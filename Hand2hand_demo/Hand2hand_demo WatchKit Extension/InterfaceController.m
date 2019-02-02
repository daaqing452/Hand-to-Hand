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
    NSLog(@"init finished");
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

- (void)parseCommand:(NSString *)command {
    if ([command isEqualToString:@"xxx"]) {
        
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
//  sensor
//
- (void)setSensorDataGetPush {
    if (!self.motionManager.deviceMotionAvailable) return;
    self.motionManager.deviceMotionUpdateInterval = 1/100.0;
    [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        if (error) return;
        CMAcceleration acceleration = motion.userAcceleration;
        CMAttitude *attitude = motion.attitude;
        CMRotationRate rotationRate = motion.rotationRate;
        NSLog(@"%f %f %f", acceleration.x, attitude.pitch, rotationRate.x);
    }];
    NSLog(@"push motion ready");
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



