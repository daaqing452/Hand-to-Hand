//
//  InterfaceController.m
//  hand2hand WatchKit Extension
//
//  Created by 鲁逸沁 on 2018/12/26.
//  Copyright © 2018年 鲁逸沁. All rights reserved.
//

#import "InterfaceController.h"
#import <CoreMotion/CoreMotion.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>
#import <WatchConnectivity/WatchConnectivity.h>


@interface InterfaceController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonTest;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonLog;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonShowFiles;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonDeleteFiles;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonSendFiles;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonBluetooth;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *label0;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *label1;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NSFileManager *fileManager;
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) WCSession *session;
@property (strong, nonatomic) NSString *documentPath;
@property (strong, nonatomic) NSString *sharedPath;

@end


@implementation InterfaceController

NSString * const SENSOR_DATA_RETRIVAL = @"push";
bool const SENSOR_SHOW_DETAIL = false;

NSString *communication = @"null";

bool logging = false;
NSString *buffer = @"";

NSMutableArray<CBPeripheral*> *devices;

- (CMMotionManager *)motionManager {
    if (!_motionManager) {
        self.motionManager = [[CMMotionManager alloc] init];
    }
    return _motionManager;
}

- (NSFileManager *)fileManager {
    if (!_fileManager) {
        self.fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}

- (NSString *)documentPath {
    if (!_documentPath) {
        self.documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    }
    return _documentPath;
}

- (NSString *)sharedPath {
    if (!_sharedPath) {
        self.sharedPath = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.pcg.hand2hand"] path];
    }
    return _sharedPath;
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    // Configure interface objects here.
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    
    if ([WCSession isSupported]) {
        self.session = [WCSession defaultSession];
        self.session.delegate = self;
        [self.session activateSession];
        communication = @"watch connectivity";
    }
    
    if ([SENSOR_DATA_RETRIVAL isEqualToString:@"push"]) {
        [self pushAccelerometer];
    } else if ([SENSOR_DATA_RETRIVAL isEqualToString:@"pull"]) {
        [self setSensorDataGetPull];
    }
    
    NSLog(@"init finished");
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
    
    if (self.motionManager.isAccelerometerAvailable) {
        [self.motionManager stopAccelerometerUpdates];
    }
    NSLog(@"bye");
}

- (void)parseCommand:(NSString *)command {
    if ([command isEqualToString:@"log on"]) {
        [self changeLogStatus:true];
    } else if ([command isEqualToString:@"log off"]) {
        [self changeLogStatus:false];
    } else {
        NSLog(@"recv message: %@", command);
    }
}

- (void)send:(NSString *)message {
    if ([communication isEqualToString:@"watch connectivity"]) {
        [self sendMessage:message];
    } else if ([communication isEqualToString:@"core bluetooth"]) {
        //
    }
}



/*
 * UI
 */
- (IBAction)doClickButtonTest:(id)sender {
    [self.label0 setText:@"test"];
    [self sendMessage:@"test"];
}

- (IBAction)doClickButtonLog:(id)sender {
    [self changeLogStatus];
}

- (IBAction)doClickButtonShowFiles:(id)sender {
    [self showFiles:self.documentPath];
}

- (IBAction)doClickButtonDeleteFiles:(id)sender {
    [self deleteFiles:self.documentPath];
}

- (IBAction)doClickButtonSendFiles:(id)sender {
    NSDirectoryEnumerator *myDirectoryEnumerator = [self.fileManager enumeratorAtPath:self.documentPath];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        [self sendFile:[self.documentPath stringByAppendingPathComponent:file]];
    }
}

- (IBAction)doClickButtonBluetooth:(id)sender {
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    devices = [NSMutableArray array];
}



/*
 * sensor
 */
- (void)pushAccelerometer {
    if (!self.motionManager.isAccelerometerAvailable) return;
    self.motionManager.accelerometerUpdateInterval = 1/100.0;
    __block int freqCnt = 0;
    NSDate *startTime = [NSDate date];
    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error) {
        if (error) return;
        CMAcceleration acceleration = accelerometerData.acceleration;
        if (SENSOR_SHOW_DETAIL) {
            freqCnt ++;
            float freq = freqCnt / (-[startTime timeIntervalSinceNow]);
            NSLog(@"%f, %f, %f", acceleration.x, acceleration.y, acceleration.z);
            NSLog(@"freqAcc: %f", freq);
        }
        if (logging) {
            [self addLogBuffer:[NSString stringWithFormat:@"acc %f %f %f", acceleration.x, acceleration.y, acceleration.z]];
        }
    }];
    NSLog(@"push ready");
}

- (void)setSensorDataGetPull {
    if (self.motionManager.isAccelerometerAvailable) {
        self.motionManager.accelerometerUpdateInterval = 1/100.0;
        [self.motionManager startAccelerometerUpdates];
    }
    [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(getSensorData:) userInfo:nil repeats:YES];
}

- (void)getSensorData:(NSTimer *)timer {
    CMAccelerometerData *data = self.motionManager.accelerometerData;
    CMAcceleration acceleration = data.acceleration;
    NSLog(@"%f, %f, %f", acceleration.x, acceleration.y, acceleration.z);
}



/*
 * log
 */
- (void)changeLogStatus:(bool)status {
    if (status == false) {
        [self.buttonLog setTitle:@"Log/Off"];
        NSString *fileName = [NSString stringWithFormat:@"log-%@-.txt", [self getTimeString:@"YYYY-MM-dd-HH-mm-ss"]];
        [self writeFile:fileName content:buffer];
        buffer = @"";
        logging = false;
    } else {
        [self.buttonLog setTitle:@"Log/On"];
        logging = true;
    }
}

- (void)changeLogStatus {
    [self changeLogStatus:!logging];
}

- (void)addLogBuffer:(NSString *)content {
    double timestamp = [[NSDate date] timeIntervalSince1970];
    buffer = [buffer stringByAppendingString:[NSString stringWithFormat:@"%f %@\n", timestamp, content]];
    if (arc4random() % 100 == 0) {
        NSLog(@"buffer: %d", buffer.length);
    }
}

- (NSString *)getTimeString:(NSString *)format {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
    NSDate *now = [NSDate date];
    return [formatter stringFromDate:now];
}



/*
 * file
 */
- (void)writeFile:(NSString *)fileName content:(NSString *)content {
    NSString *filePath = [self.documentPath stringByAppendingPathComponent:fileName];
    bool ifSuccess = [content writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"write file %@: %@", ifSuccess ? @"Y" : @"N", fileName);
}

- (void)showFiles:(NSString *)path {
    NSLog(@"show files: %@", path);
    NSDirectoryEnumerator *myDirectoryEnumerator = [self.fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        NSLog(@"file %@", file);
    }
}

- (void)deleteFiles:(NSString *)path {
    NSDirectoryEnumerator *myDirectoryEnumerator = [self.fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        NSString *filePath = [self.documentPath stringByAppendingPathComponent:file];
        bool ifSuccess = [self.fileManager removeItemAtPath:filePath error:nil];
        NSLog(@"delete file %@: %@", ifSuccess ? @"Y" : @"N", file);
    }
}



/*
 * watch connectivity
 */
- (void)sendData:(NSDictionary *)dict {
    [self.session sendMessage:dict replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
        // no reply?
    } errorHandler:^(NSError * _Nonnull error) {
        // do nothing
    }];
}

- (void)sendMessage:(NSString *)message {
    [self sendData:@{@"message": message}];
}

- (void)sendFile:(NSString *)filePath {
    NSLog(@"try send: %@", filePath);
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    [self.session transferFile:fileUrl metadata:nil];
}

- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *,id> *)dict replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * __nonnull))replyHandler {
    [self parseCommand:dict[@"message"]];
}

- (void)alert:(NSString *)message {
    WKAlertAction *actionDone = [WKAlertAction actionWithTitle:@"完成" style:WKAlertActionStyleDefault handler:^{
    }];
    WKAlertAction *actionDestruction = [WKAlertAction actionWithTitle:@"毁灭" style:WKAlertActionStyleDestructive handler:^{
    }];
    [self presentAlertControllerWithTitle:@"消息" message:message preferredStyle:WKAlertControllerStyleActionSheet actions:@[actionDone, actionDestruction]];
}



/*
 * bluetooth
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStatePoweredOn:
            NSLog(@"bluetooth power on");
            //[self appendInfo:@"bluetooth power on"];
            [self startScan];
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"bluetooth power off");
            //[self appendInfo:@"bluetooth power off"];
            break;
        default:
            break;
    }
}

- (void)startScan {
    NSLog(@"start scan...");
    //[self appendInfo:@"start scan..."];
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    [self performSelector:@selector(stopScan) withObject:nil afterDelay:5];
}

- (void)stopScan {
    NSLog(@"stop scan...");
    //[self appendInfo:@"stop scan..."];
    [self.centralManager stopScan];
}

- (void)centralManager:(CBCentralManager *)centralManager didDiscoverPeripheral:(nonnull CBPeripheral *)peripheral advertisementData:(nonnull NSDictionary<NSString *,id> *)advertisementData RSSI:(nonnull NSNumber *)RSSI {
    if ([peripheral.name isEqualToString:@"iPhone LU"]) {
        NSLog(@"find device: %@", peripheral.name);
        //[self appendInfo:[NSString stringWithFormat:@"find device: %@", peripheral.name]];
        [devices addObject:peripheral];
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"connect device: %@", peripheral.name);
    [self.label0 setText:@"connected"];
    //[self appendInfo:[NSString stringWithFormat:@"connect device: %@", peripheral.name]];
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    communication = @"core bluetooth";
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"connect device fail: %@ - %@", peripheral.name, error);
    //[self appendInfo:[NSString stringWithFormat:@"connect device fail: %@ - %@", peripheral.name, error]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"disconnect device: %@ - %@", peripheral.name, error);
    //[self appendInfo:[NSString stringWithFormat:@"disconnect device: %@ - %@", peripheral.name, error]];
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
            //
        }
        if (properties & CBCharacteristicPropertyWrite) {
            //
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

@end
