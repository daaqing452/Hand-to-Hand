//
//  InterfaceController.m
//  hand2hand WatchKit Extension
//
//  Created by Yiqin Lu on 2018/12/26.
//  Copyright © 2018 Yiqin Lu. All rights reserved.
//

#import "InterfaceController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>
#import <WatchConnectivity/WatchConnectivity.h>

#define LBLog(format, ...) [self.label0 setText:[NSString stringWithFormat:(format), ##__VA_ARGS__]]


@interface InterfaceController () <WCSessionDelegate, CBCentralManagerDelegate, CBPeripheralDelegate, HKWorkoutSessionDelegate>

@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonTest;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonLog;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonShowFiles;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonDeleteFiles;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonSendFiles;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonCommunication;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *label0;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) HKWorkoutConfiguration *workoutConfiguration;
@property (strong, nonatomic) HKHealthStore *healthScore;
@property (strong, nonatomic) HKWorkoutSession *workoutSession;

@end


@implementation InterfaceController

//  general
WKInterfaceDevice *device;
NSFileManager *fileManager;
NSString *documentPath;
NSString *sharedPath;

//  sensor
NSString * const SENSOR_DATA_RETRIVAL = @"push";
bool const SENSOR_SHOW_DETAIL = false;
//CMMotionManager *motionManager;

//  communication
WCSession *wcsession;
NSString *communication = @"null";
bool watchConnectivityTestFlag;

//  log
int const LOG_BUFFER_MAX_SIZE = 16384;
bool const LOG_SHOW_FILE_SIZE = true;
bool logging = false;
NSString *buffer = @"";
NSString *logFileName;

//  bluetooth
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
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    
    self.workoutConfiguration = [[HKWorkoutConfiguration alloc] init];
    self.workoutConfiguration.activityType = HKWorkoutActivityTypeRunning;
    self.workoutConfiguration.locationType = HKWorkoutSessionLocationTypeOutdoor;
    self.healthScore = [[HKHealthStore alloc] init];
    self.workoutSession = [[HKWorkoutSession alloc] initWithHealthStore:self.healthScore configuration:self.workoutConfiguration error:nil];
    [self.workoutSession startActivityWithDate:[NSDate date]];
    
    device = [WKInterfaceDevice currentDevice];
    fileManager = [NSFileManager defaultManager];
    documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    sharedPath = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.pcg.hand2hand"] path];
    
    //[self startCommunication];
    
    self.motionManager = [[CMMotionManager alloc] init];
    if ([SENSOR_DATA_RETRIVAL isEqualToString:@"push"]) {
        [self setSensorDataGetPush];
    } else if ([SENSOR_DATA_RETRIVAL isEqualToString:@"pull"]) {
        [self setSensorDataGetPull];
    }
    
    LBLog(@"%@", device.name);
    NSLog(@"init finished");
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
    NSLog(@"bye");
}

- (void)parseCommand:(NSString *)command {
    if ([command isEqualToString:@"log on"]) {
        [self changeLogStatus:true];
    } else if ([command isEqualToString:@"log off"]) {
        [self changeLogStatus:false];
    } else if ([command isEqualToString:@"test watch connectivity success"]) {
        watchConnectivityTestFlag = true;
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
- (IBAction)doClickButtonTest:(id)sender {
    LBLog(@"test");
    [self sendMessage:@"test"];
}

- (IBAction)doClickButtonLog:(id)sender {
    [self changeLogStatus];
}

- (IBAction)doClickButtonShowFiles:(id)sender {
    [self showFiles:documentPath];
}

- (IBAction)doClickButtonDeleteFiles:(id)sender {
    [self deleteFiles:documentPath];
}

- (IBAction)doClickButtonSendFiles:(id)sender {
    NSDirectoryEnumerator *myDirectoryEnumerator = [fileManager enumeratorAtPath:documentPath];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        [self sendFile:[documentPath stringByAppendingPathComponent:file]];
    }
}

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
    __block int freqCnt = 0;
    NSDate *startTime = [NSDate date];
    [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        if (error) return;
        CMAcceleration acceleration = motion.userAcceleration;
        CMAttitude *attitude = motion.attitude;
        CMRotationRate rotationRate = motion.rotationRate;
        //CMAcceleration gravity = motion.gravity;
        //CMCalibratedMagneticField magneticField = motion.magneticField;
        if (SENSOR_SHOW_DETAIL) {
            freqCnt ++;
            float freq = freqCnt / (-[startTime timeIntervalSinceNow]);
            NSLog(@"acc %f %f %f", acceleration.x, acceleration.y, acceleration.z);
            NSLog(@"freqAcc: %f", freq);
        }
        if (logging) {
            buffer = [buffer stringByAppendingString:[NSString stringWithFormat:@"time %f\nacc %f %f %f\natt %f %f %f\nrot %f %f %f\n", motion.timestamp, acceleration.x, acceleration.y, acceleration.z, attitude.pitch, attitude.roll, attitude.yaw, rotationRate.x, rotationRate.y, rotationRate.z]];
            if (arc4random() % 100 == 0) {
                NSLog(@"buffer: %d", buffer.length);
            }
            if (buffer.length > LOG_BUFFER_MAX_SIZE) {
                [self writeFile:logFileName content:buffer];
                buffer = @"";
            }
        }
    }];
    NSLog(@"push motion ready");
}

- (void)setSensorDataGetPull {
    if (self.motionManager.isAccelerometerAvailable) {
        self.motionManager.accelerometerUpdateInterval = 1/100.0;
        [self.motionManager startAccelerometerUpdates];
    }
    [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(getSensorData:) userInfo:nil repeats:YES];
}

- (void)getSensorData:(NSTimer *)timer {
    if (logging) {
        CMAccelerometerData *accelerationData = self.motionManager.accelerometerData;
        CMAcceleration acceleration = accelerationData.acceleration;
        NSLog(@"acc %f %f %f", acceleration.x, acceleration.y, acceleration.z);
    }
}



//
//  log
//
- (void)changeLogStatus:(bool)status {
    if (status == false) {
        [self writeFile:logFileName content:buffer];
        buffer = @"";
        [self.buttonLog setTitle:@"Log: Off"];
        logging = false;
    } else {
        [self.buttonLog setTitle:@"Log: On"];
        logFileName = [NSString stringWithFormat:@"log-%@-%@.txt", [self getTimeString:@"YYYYMMdd-HHmmss"], [device.name stringByReplacingOccurrencesOfString:@" " withString:@""]];
        logging = true;
    }
}

- (void)changeLogStatus {
    [self changeLogStatus:!logging];
}

- (NSString *)getTimeString:(NSString *)format {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
    NSDate *now = [NSDate date];
    return [formatter stringFromDate:now];
}



//
//  file
//
- (void)writeFile:(NSString *)fileName content:(NSString *)content {
    NSString *filePath = [documentPath stringByAppendingPathComponent:fileName];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (fileHandle == nil) {
        bool ifSuccess = [content writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSLog(@"write file %@: %@", ifSuccess ? @"Y" : @"N", fileName);
    } else {
        [fileHandle truncateFileAtOffset:[fileHandle seekToEndOfFile]];
        [fileHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
        if (LOG_SHOW_FILE_SIZE) {
            long long size = [[fileManager attributesOfItemAtPath:filePath error:nil] fileSize];
            [self sendMessage:[NSString stringWithFormat:@"do write %lld", size]];
        }
    }
}

- (void)showFiles:(NSString *)path {
    NSLog(@"show files: %@", path);
    NSDirectoryEnumerator *myDirectoryEnumerator = [fileManager enumeratorAtPath:path];
    NSString *file;
    int fileCount = 0;
    while ((file = [myDirectoryEnumerator nextObject])) {
        if ([[file pathExtension] isEqualToString:@"txt"]) {
            NSLog(@"file %@", file);
            fileCount += 1;
        }
    }
    [self.buttonShowFiles setTitle:[NSString stringWithFormat:@"Show Files: %d", fileCount]];
}

- (void)deleteFiles:(NSString *)path {
    NSDirectoryEnumerator *myDirectoryEnumerator = [fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        NSString *filePath = [documentPath stringByAppendingPathComponent:file];
        bool ifSuccess = [fileManager removeItemAtPath:filePath error:nil];
        NSLog(@"delete file %@: %@", ifSuccess ? @"Y" : @"N", file);
    }
}



//
//  watch connectivity
//
- (void)sendDataByWatchConnectivity:(NSDictionary *)dict {
    [wcsession sendMessage:dict replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
        // ignore
    } errorHandler:^(NSError * _Nonnull error) {
        if ([dict[@"message"] isEqualToString:@"test watch connectivity"]) {
            // cannot connect to paired counterpart, use core bluetooth
            // error.code
            //      7007 WatchConnectivity session on paired device is not reachable.
            //      7012 Message reply took too long.
            //      7017 Transfer timed out.
        }
    }];
}

- (void)sendMessageByWatchConnectivity:(NSString *)message {
    [self sendDataByWatchConnectivity:@{@"message": message}];
}

- (void)sendFile:(NSString *)filePath {
    if (true) {
    //if ([communication isEqualToString:@"watch connectivity"]) {
        NSLog(@"send file: %@", filePath);
        NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
        [wcsession transferFile:fileUrl metadata:nil];
    }
}

- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *,id> *)dict replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * __nonnull))replyHandler {
    [self parseCommand:dict[@"message"]];
}

- (void)session:(nonnull WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
}

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *,id> *)applicationContext {
    LBLog(@"did %@", applicationContext[@"message"]);
}

/*- (void)alert:(NSString *)message {
    WKAlertAction *actionDone = [WKAlertAction actionWithTitle:@"完成" style:WKAlertActionStyleDefault handler:^{
    }];
    WKAlertAction *actionDestruction = [WKAlertAction actionWithTitle:@"毁灭" style:WKAlertActionStyleDestructive handler:^{
    }];
    [self presentAlertControllerWithTitle:@"消息" message:message preferredStyle:WKAlertControllerStyleActionSheet actions:@[actionDone, actionDestruction]];
}*/



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
