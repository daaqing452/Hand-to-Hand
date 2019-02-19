//
//  InterfaceController.m
//  Hand2hand_demo WatchKit Extension
//
//  Created by Yiqin Lu on 2019/1/31.
//  Copyright © 2019 Yiqin Lu. All rights reserved.
//

#import "InterfaceController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>
#import <WatchConnectivity/WatchConnectivity.h>

#define LBLog(format, ...) [self.label0 setText:[NSString stringWithFormat:(format), ##__VA_ARGS__]]


@interface InterfaceController () <WCSessionDelegate, CBCentralManagerDelegate, CBPeripheralDelegate, HKWorkoutSessionDelegate>

@property (weak, nonatomic) IBOutlet WKInterfaceLabel *label0;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonCommunication;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) HKWorkoutConfiguration *workoutConfiguration;
@property (strong, nonatomic) HKHealthStore *healthScore;
@property (strong, nonatomic) HKWorkoutSession *workoutSession;

@end


@implementation InterfaceController

//  general
WKInterfaceDevice *device;

//  communication
WCSession *wcsession;
NSString *communication = @"null";
bool watchConnectivityTestFlag;

//  core bluetooth
CBCentralManager *centralManager;
NSMutableArray<CBPeripheral*> *peripheralDevices;
CBPeripheral *subscribedPeripheral;
CBCharacteristic *subscribedCharacteristic;


- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    if ([WCSession isSupported]) {
        wcsession = [WCSession defaultSession];
        wcsession.delegate = self;
        [wcsession activateSession];
    }
}

- (void)willActivate {
    [super willActivate];
    
    self.workoutConfiguration = [[HKWorkoutConfiguration alloc] init];
    self.workoutConfiguration.activityType = HKWorkoutActivityTypeRunning;
    self.workoutConfiguration.locationType = HKWorkoutSessionLocationTypeOutdoor;
    self.healthScore = [[HKHealthStore alloc] init];
    self.workoutSession = [[HKWorkoutSession alloc] initWithHealthStore:self.healthScore configuration:self.workoutConfiguration error:nil];
    [self.workoutSession startActivityWithDate:[NSDate date]];
    
    device = [WKInterfaceDevice currentDevice];
    
    self.motionManager = [[CMMotionManager alloc] init];
    [self setSensorDataGetPush];
    
    LBLog(@"%@", device.name);
    //NSLog(@"init finished");
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

- (void)parseCommand:(NSString *)command {
    if ([command isEqualToString:@"test watch connectivity success"]) {
        watchConnectivityTestFlag = true;
    } else if ([command isEqualToString:@"start calibration"]) {
        calibrationState = C_Listening;
        minValue0 = 0;
    } else {
        NSLog(@"recv: %@", command);
    }
}

- (void)sendMessage:(NSString *)message {
    if ([communication isEqualToString:@"core bluetooth"]) {
        [self sendMessageByCoreBluetooth:message];
    } else {
        [self sendMessageByWatchConnectivity:message];
    }
}

- (void)changeCommunication:(NSString *)newCommunication {
    communication = newCommunication;
    if ([communication isEqualToString:@"watch connectivity"]) {
        [self.buttonCommunication setTitle:@"Comm: Watch Con..."];
    } else if ([communication isEqualToString:@"core bluetooth"]) {
        [self.buttonCommunication setTitle:@"Comm: Core Blue..."];
    } else if ([communication isEqualToString:@"null"]) {
        [self.buttonCommunication setTitle:@"Comm: Null"];
    } else {
        [self.buttonCommunication setTitle:@"Comm: Error"];
    }
}

- (void)connectByCoreBluetooth {
    if (centralManager == nil) {
        centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        peripheralDevices = [NSMutableArray array];
    } else {
        [self startScan];
    }
}

- (void)timeredWatchConnectivity:(NSTimer *)timer {
    if (watchConnectivityTestFlag) {
        [self changeCommunication:@"watch connectivity"];
    } else {
        [self connectByCoreBluetooth];
    }
}

- (void)startCommunication {
    if ([communication isEqualToString:@"core bluetooth"]) {
        [self connectByCoreBluetooth];
    } else {
        wcsession = [WCSession defaultSession];
        wcsession.delegate = self;
        [wcsession activateSession];
        watchConnectivityTestFlag = false;
        [self sendMessageByWatchConnectivity:@"test watch connectivity"];
        [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timeredWatchConnectivity:) userInfo:nil repeats:NO];
    }
}



//
//  UI
//
- (IBAction)doClickButtonCommunication:(id)sender {
    [self changeCommunication:@"null"];
    [self startCommunication];
}



//
//  --- sensor ---
//
const double REPORT_ACC_THREHOLD = 100;

const double CALIBRATION_ACC_Z_THRESHOLD = -5.0;
const double CALIBRATION_AFTER_PEAK_TIME = 0.1;
enum CalibrationStates { C_Idle, C_Listening, C_PeakOccur } calibrationState = C_Idle;
double minValue0;
double calibratedTimestamp = 0;
double prevCalibratedTimestamp = 0;

const double DETECTION_ZERO_THRESHOLD = 2.0;
const double DETECTION_ZERO1ST_TIME = 0.2;
const double DETECTION_ZERO2ND_TIME = 0.2;
const double DETECTION_ROT_X_THRESHOLD_MIN = -15.0;
const double DETECTION_ROT_X_THRESHOLD_MAX = 12.0;
const double DETECTION_MAX_BETWEEN_PEAK_TIME = 0.35;
enum DetectionStates { D_Idle, D_Zero1st, D_MinPeak, D_MaxPeak } detectionState = D_Idle;
bool zeroing = false;
double zeroStartTimestamp = -1;
int zeroId = 0;
int goodZeroId;
double minValue1;
double maxValue1;
double minPeakTimestamp;
double maxPeakTimestamp;

enum DetectionStates prevDetectionState = D_MaxPeak;

- (void)setSensorDataGetPush {
    if (!self.motionManager.deviceMotionAvailable) return;
    self.motionManager.deviceMotionUpdateInterval = 1/100.0;
    [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        if (error) return;
        
        CMAcceleration acceleration = motion.userAcceleration;
        //CMAttitude *attitude = motion.attitude;
        CMRotationRate rotationRate = motion.rotationRate;
        double nowTimestamp = motion.timestamp - calibratedTimestamp;
        
        if (fabs(acceleration.x) > REPORT_ACC_THREHOLD || fabs(acceleration.y) > REPORT_ACC_THREHOLD || fabs(acceleration.z) > REPORT_ACC_THREHOLD) {
            NSLog(@"%f %f %f %f", motion.timestamp, acceleration.x, acceleration.y, acceleration.z);
        }
        
        // calibration
        if (calibrationState == C_Listening || calibrationState == C_PeakOccur) {
            double value = acceleration.z;
            if (value < CALIBRATION_ACC_Z_THRESHOLD) {
                calibrationState = C_PeakOccur;
                if (value < minValue0) {
                    minValue0 = value;
                    calibratedTimestamp = motion.timestamp;
                }
            } else {
                if (calibrationState == C_PeakOccur && motion.timestamp - calibratedTimestamp > CALIBRATION_AFTER_PEAK_TIME) {
                    [self sendMessage:[NSString stringWithFormat:@"calibration time %@: %f", device.name, calibratedTimestamp - prevCalibratedTimestamp]];
                    prevCalibratedTimestamp = calibratedTimestamp;
                    calibrationState = C_Idle;
                }
            }
        }
        
        // detection
        if (fabs(rotationRate.x) < DETECTION_ZERO_THRESHOLD) {
            if (!zeroing) {
                zeroStartTimestamp = nowTimestamp;
                zeroId++;
            }
            zeroing = true;
        } else {
            zeroing = false;
        }
        switch (detectionState) {
            case D_Idle:
                // long zero then listen peak
                if (zeroing && nowTimestamp - zeroStartTimestamp > DETECTION_ZERO1ST_TIME) {
                    detectionState = D_Zero1st;
                    minValue1 = 1;
                    goodZeroId = zeroId;
                }
                break;
            case D_Zero1st:
                // find min peak
                if (rotationRate.x < minValue1) {
                    minValue1 = rotationRate.x;
                    minPeakTimestamp = nowTimestamp;
                }
                /*if (zeroing && goodZeroId != zeroId) {
                    NSLog(@"minv %f", minValue1);
                }*/
                // zero after min peak
                if (zeroing && minValue1 < DETECTION_ROT_X_THRESHOLD_MIN) {
                    detectionState = D_MinPeak;
                    goodZeroId = zeroId;
                    maxValue1 = -1;
                }
                // zero -> non-zero & no peak -> zero ==> failed
                if (goodZeroId != zeroId) {
                    detectionState = D_Idle;
                }
                break;
            case D_MinPeak:
                // find max peak
                if (rotationRate.x > maxValue1) {
                    maxValue1 = rotationRate.x;
                    maxPeakTimestamp = nowTimestamp;
                }
                /*if (zeroing && goodZeroId != zeroId) {
                    NSLog(@"maxv %f", maxValue1);
                }*/
                // zero after max peak
                if (zeroing && maxValue1 > DETECTION_ROT_X_THRESHOLD_MAX) {
                    detectionState = D_MaxPeak;
                    goodZeroId = zeroId;
                }
                // zero -> non-zero & no peak -> zero ==> failed
                if (goodZeroId != zeroId) {
                    detectionState = D_Idle;
                }
                // too long between two peaks
                if (nowTimestamp - minPeakTimestamp > DETECTION_MAX_BETWEEN_PEAK_TIME) {
                    detectionState = D_Idle;
                }
                break;
            case D_MaxPeak:
                // detect success
                if (nowTimestamp - maxPeakTimestamp > DETECTION_ZERO2ND_TIME) {
                    NSLog(@"delimiter!\n\n\n\n");
                    detectionState = D_Idle;
                }
                // zero last too short
                if (!zeroing) {
                    detectionState = D_Idle;
                }
                break;
        }
        
        if (detectionState != prevDetectionState) {
            NSLog(@"s%d", detectionState);
        }
        prevDetectionState = detectionState;
    }];
    //NSLog(@"push motion ready");
}



//
//  watch connectivity
//
- (void)sendDataByWatchConnectivity:(NSDictionary *)dict {
    [wcsession sendMessage:dict replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
        // ignore
    } errorHandler:^(NSError * _Nonnull error) {
        // error
    }];
}

- (void)sendMessageByWatchConnectivity:(NSString *)message {
    [self sendDataByWatchConnectivity:@{@"message": message}];
}

- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *,id> *)dict replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * __nonnull))replyHandler {
    [self parseCommand:dict[@"message"]];
}

- (void)session:(nonnull WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
}



//
//  core bluetooth
//
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStatePoweredOn:
            NSLog(@"core bluetooth power on");
            [self startScan];
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"core bluetooth power off");
            break;
        default:
            break;
    }
}

- (void)startScan {
    NSLog(@"start scan...");
    [centralManager scanForPeripheralsWithServices:nil options:nil];
    [self performSelector:@selector(stopScan) withObject:nil afterDelay:5];
}

- (void)stopScan {
    NSLog(@"stop scan...");
    [centralManager stopScan];
}

- (void)centralManager:(CBCentralManager *)centralManager didDiscoverPeripheral:(nonnull CBPeripheral *)peripheral advertisementData:(nonnull NSDictionary<NSString *,id> *)advertisementData RSSI:(nonnull NSNumber *)RSSI {
    if ([peripheral.name isEqualToString:@"iPhone LU"]) {
        NSLog(@"find device: %@", peripheral.name);
        [peripheralDevices addObject:peripheral];
        [centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    NSLog(@"connect device: %@", peripheral.name);
    [self changeCommunication:@"core bluetooth"];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"connect device fail: %@ - %@", peripheral.name, error);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [peripheralDevices removeObject:peripheral];
    NSLog(@"disconnect device: %@ - %@", peripheral.name, error);
    [self changeCommunication:@"null"];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        NSString *uuid = [service.UUID UUIDString];
        if ([uuid isEqualToString:@"FEF0"]) {
            NSLog(@"find service: %@", uuid);
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"find characristic %@", characteristic.UUID);
        CBCharacteristicProperties properties = characteristic.properties;
        if (properties & CBCharacteristicPropertyRead) {
            // do nothing
        }
        if (properties & CBCharacteristicPropertyWrite) {
            subscribedPeripheral = peripheral;
            subscribedCharacteristic = characteristic;
        }
        if (properties & CBCharacteristicPropertyNotify) {
            NSLog(@"subscribe: %@", characteristic.UUID);
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSString *command = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    [self parseCommand:command];
}

- (void)sendMessageByCoreBluetooth:(NSString *)message {
    [subscribedPeripheral writeValue:[message dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:subscribedCharacteristic type:CBCharacteristicWriteWithoutResponse];
}



//
//  workout
//
- (void)workoutSession:(nonnull HKWorkoutSession *)workoutSession didChangeToState:(HKWorkoutSessionState)toState fromState:(HKWorkoutSessionState)fromState date:(nonnull NSDate *)date {
}

- (void)workoutSession:(nonnull HKWorkoutSession *)workoutSession didFailWithError:(nonnull NSError *)error {
}

- (void)workoutSession:(HKWorkoutSession *)workoutSession didGenerateEvent:(HKWorkoutEvent *)event {
}


@end



