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
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonTest;

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
    NSLog(@"init finished");
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
    } else if ([command isEqualToString:@"recognition on"]) {
        recognizing = true;
    } else if ([command isEqualToString:@"recognition off"]) {
        recognizing = false;
    } else if ([command isEqualToString:@"hello"]) {
        LBLog(@"hello");
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

- (void)sendData:(NSData *)data {
    if ([communication isEqualToString:@"core bluetooth"]) {
        [self sendDataByCoreBluetooth:data];
    } else {
        [self sendDataByWatchConnectivity:@{@"message": @"features", @"data": data}];
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

- (IBAction)doClickButtonTest:(id)sender {
    [self sendMessageByCoreBluetooth:@"test"];
}

- (void)okok {
    NSString *sa = @"";
    for (int i = 0; i < 96; i++) {
        sa = [sa stringByAppendingString:@"a"];
    }
    [self sendDataByCoreBluetooth:[sa dataUsingEncoding:NSUTF8StringEncoding]];
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

//#define DETECTION_DEBUG
const double DETECTION_ZERO_THRESHOLD = 3.5;
const double DETECTION_ZERO1ST_TIME = 0.2;
const double DETECTION_ZERO2ND_TIME = 0.1;
const double DETECTION_ROT_X_THRESHOLD_MIN = -10.0;
const double DETECTION_ROT_X_THRESHOLD_MAX = 10.0;
const double DETECTION_MAX_BETWEEN_PEAK_TIME = 0.35;
const double DETECTION_ENERGY_THRESHOLD = 300;
enum DetectionStates { D_Idle, D_Zero1st, D_MinPeak, D_MaxPeak } detectionState = D_Idle, prevDetectionState;
bool zeroing = false;
double zeroStartTimestamp = -1;
int zeroId = 0;
int goodZeroId;
double minValue1;
double maxValue1;
double minPeakTimestamp;
double maxPeakTimestamp;
double afterPeakEnergy;

- (void)setSensorDataGetPush {
    if (!self.motionManager.deviceMotionAvailable) return;
    self.motionManager.deviceMotionUpdateInterval = 1/100.0;
    [self initArrays];
    
    // push
    [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        if (error) return;
        
        // get motion
        double nowTimestamp = motion.timestamp - calibratedTimestamp;
        CMAcceleration acceleration = motion.userAcceleration;
        //CMAttitude *attitude = motion.attitude;
        CMRotationRate rotationRate = motion.rotationRate;
        if (fabs(acceleration.x) > REPORT_ACC_THREHOLD || fabs(acceleration.y) > REPORT_ACC_THREHOLD || fabs(acceleration.z) > REPORT_ACC_THREHOLD) {
            NSLog(@"%f %f %f %f", motion.timestamp, acceleration.x, acceleration.y, acceleration.z);
        }
        
        if (recognizing) {
            [self addFrame:motion];
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
#ifdef DETECTION_DEBUG
                if (zeroing && goodZeroId != zeroId) {
                    NSLog(@"minv %f", minValue1);
                }
#endif
                // zero after min peak
                if (zeroing && minValue1 < DETECTION_ROT_X_THRESHOLD_MIN) {
                    detectionState = D_MinPeak;
                    goodZeroId = zeroId;
                    maxValue1 = -1;
                    break;
                }
                // zero -> non-zero & no peak -> zero ==> failed
                if (goodZeroId != zeroId) {
                    detectionState = D_Idle;
                    break;
                }
                break;
            case D_MinPeak:
                // find max peak
                if (rotationRate.x > maxValue1) {
                    maxValue1 = rotationRate.x;
                }
#ifdef DETECTION_DEBUG
                if (zeroing && goodZeroId != zeroId) {
                    NSLog(@"maxv %f", maxValue1);
                }
#endif
                // zero after max peak
                if (zeroing && maxValue1 > DETECTION_ROT_X_THRESHOLD_MAX) {
                    detectionState = D_MaxPeak;
                    maxPeakTimestamp = nowTimestamp;
                    afterPeakEnergy = 0;
                    break;
                }
                // zero -> non-zero & no peak -> zero ==> failed
                if (goodZeroId != zeroId) {
                    detectionState = D_Idle;
                    break;
                }
                // too long between two peaks
                if (nowTimestamp - minPeakTimestamp > DETECTION_MAX_BETWEEN_PEAK_TIME) {
                    detectionState = D_Idle;
                    break;
                }
                break;
            case D_MaxPeak:
                // detect after max peak energy
                afterPeakEnergy += pow(rotationRate.x, 2);
                if (nowTimestamp - maxPeakTimestamp > DETECTION_ZERO2ND_TIME) {
#ifdef DETECTION_DEBUG
                    NSLog(@"energy: %f", afterPeakEnergy);
#endif
                    if (afterPeakEnergy < DETECTION_ENERGY_THRESHOLD) {
                        [self sendMessage:@"detect delimiter"];
                    }
                    detectionState = D_Idle;
                }
                break;
        }
        
#ifdef DETECTION_DEBUG
        if (detectionState != prevDetectionState) {
            NSLog(@"s%d", detectionState);
        }
        prevDetectionState = detectionState;
#endif
    }];
    //NSLog(@"push motion ready");
}



// recognition
const int MOTION_ARRAY_CAPACITY = 50;
const int MOTION_ARRAY_CUT_OFF = 25;
bool recognizing = false;
NSMutableArray *accxArray, *accyArray, *acczArray, *attxArray, *attyArray, *attzArray;

- (void)initArrays {
    accxArray = [[NSMutableArray alloc] init];
    accyArray = [[NSMutableArray alloc] init];
    acczArray = [[NSMutableArray alloc] init];
    attxArray = [[NSMutableArray alloc] init];
    attyArray = [[NSMutableArray alloc] init];
    attzArray = [[NSMutableArray alloc] init];
}

- (void)addFrame:(CMDeviceMotion *)motion {
    [accxArray addObject:[NSNumber numberWithDouble:motion.userAcceleration.x]];
    [accyArray addObject:[NSNumber numberWithDouble:motion.userAcceleration.y]];
    [acczArray addObject:[NSNumber numberWithDouble:motion.userAcceleration.z]];
    [attxArray addObject:[NSNumber numberWithDouble:motion.attitude.pitch]];
    [attyArray addObject:[NSNumber numberWithDouble:motion.attitude.roll]];
    [attzArray addObject:[NSNumber numberWithDouble:motion.attitude.yaw]];
    if (accxArray.count >= MOTION_ARRAY_CAPACITY) {
        [self processFrames];
        [accxArray removeObjectsInRange:NSMakeRange(0, MOTION_ARRAY_CUT_OFF)];
        [accyArray removeObjectsInRange:NSMakeRange(0, MOTION_ARRAY_CUT_OFF)];
        [acczArray removeObjectsInRange:NSMakeRange(0, MOTION_ARRAY_CUT_OFF)];
        [attxArray removeObjectsInRange:NSMakeRange(0, MOTION_ARRAY_CUT_OFF)];
        [attyArray removeObjectsInRange:NSMakeRange(0, MOTION_ARRAY_CUT_OFF)];
        [attzArray removeObjectsInRange:NSMakeRange(0, MOTION_ARRAY_CUT_OFF)];
    }
}

- (NSArray *)getFeature:(NSArray *)array {
    double qmin = 1e20, qmax = -1e20, qmean = 0, qstd = 0;
    for (int i = 0; i < array.count; i++) {
        double value = [array[i] doubleValue];
        qmin = fmin(qmin, value);
        qmax = fmax(qmax, value);
        qmean += value;
    }
    qmean /= array.count;
    for (int i = 0; i < array.count; i++) {
        double value = [array[i] doubleValue];
        qstd += pow(value - qmean, 2);
    }
    qstd = sqrt(qstd / array.count);
    return [NSArray arrayWithObjects:[NSNumber numberWithDouble:qmin], [NSNumber numberWithDouble:qmax], [NSNumber numberWithDouble:qmean], [NSNumber numberWithDouble:qstd], nil];
}

- (void)processFrames {
    NSMutableArray *features = [[NSMutableArray alloc] init];
    [features addObjectsFromArray:[self getFeature:accxArray]];
    [features addObjectsFromArray:[self getFeature:accyArray]];
    [features addObjectsFromArray:[self getFeature:acczArray]];
    [features addObjectsFromArray:[self getFeature:attxArray]];
    [features addObjectsFromArray:[self getFeature:attyArray]];
    [features addObjectsFromArray:[self getFeature:attzArray]];
    int length = features.count * 2 + 1;
    Byte bytes[length];
    bytes[0] = [device.name isEqualToString:@"Watch L"] ? 0 : ([device.name isEqualToString:@"Watch R"] ? 1 : 2);
    for (int i = 0; i < features.count; i++) {
        double value = [features[i] doubleValue];
        int intValue = round(value * 1000);
        intValue = intValue >  32767 ?  32767 : intValue;
        intValue = intValue < -32768 ? -32768 : intValue;
        bytes[i * 2 + 1] = (intValue & 0xff00) >> 8;
        bytes[i * 2 + 2] = intValue & 0x00ff;
    }
    NSData *data = [[NSData alloc] initWithBytes:bytes length:length];
    [self sendData:data];
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

NSString *const CHARACTERISTIC_UUID_MESSAGE_RECV = @"FEF2";
NSString *const CHARACTERISTIC_UUID_DATA_RECV = @"FEF3";
CBCentralManager *centralManager;
NSMutableArray<CBPeripheral*> *peripheralDevices;
CBPeripheral *writablePeripheral = nil;
CBCharacteristic *characteristicMessageRecv = nil, *characteristicDataRecv = nil;

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
        CBCharacteristicProperties properties = characteristic.properties;
        if (properties & CBCharacteristicPropertyRead) {
            // do nothing
        }
        if (properties & CBCharacteristicPropertyWrite) {
            NSLog(@"writable: %@", characteristic.UUID);
            if ([[NSString stringWithFormat:@"%@", characteristic.UUID] isEqualToString:CHARACTERISTIC_UUID_MESSAGE_RECV]) characteristicMessageRecv = characteristic;
            if ([[NSString stringWithFormat:@"%@", characteristic.UUID] isEqualToString:CHARACTERISTIC_UUID_DATA_RECV]) characteristicDataRecv = characteristic;
            writablePeripheral = peripheral;
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
    if (error) NSLog(@"peripheral error %@", error);
}

// can only send maximum 512 bytes?
- (void)sendMessageByCoreBluetooth:(NSString *)message {
    if (writablePeripheral == nil || characteristicMessageRecv == nil) return;
    [writablePeripheral writeValue:[message dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:characteristicMessageRecv type:CBCharacteristicWriteWithoutResponse];
}

- (void)sendDataByCoreBluetooth:(NSData *)data {
    if (writablePeripheral == nil || characteristicDataRecv == nil) return;
    [writablePeripheral writeValue:data forCharacteristic:characteristicDataRecv type:CBCharacteristicWriteWithoutResponse];
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



