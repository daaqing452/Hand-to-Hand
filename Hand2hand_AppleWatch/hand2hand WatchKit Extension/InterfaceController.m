//
//  InterfaceController.m
//  hand2hand WatchKit Extension
//
//  Created by 鲁逸沁 on 2018/12/26.
//  Copyright © 2018年 鲁逸沁. All rights reserved.
//

#import "InterfaceController.h"


@interface InterfaceController ()

@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonTest;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonLog;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonShowFiles;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonDeleteFiles;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *buttonSendFiles;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelTest;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NSFileManager *fileManager;
@property (strong, nonatomic) WCSession *session;
@property (strong, nonatomic) NSString *documentPath;
@property (strong, nonatomic) NSString *sharedPath;

@end


@implementation InterfaceController

NSString * const SENSOR_DATA_RETRIVAL = @"push";
bool const SENSOR_SHOW_DETAIL = false;

bool logging = false;
NSString *buffer = @"";

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



/*
 * UI
 */
- (IBAction)doClickButtonTest:(id)sender {
    [self.labelTest setText:@"test"];
    [self sendMessage:@"test"];
    [self writeFile:@"b.txt" content:@"hi"];
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
    NSString *op = dict[@"message"];
    if ([op isEqualToString:@"log on"]) {
        [self changeLogStatus:true];
    } else if ([op isEqualToString:@"log off"]) {
        [self changeLogStatus:false];
    } else {
        NSLog(@"recv message: %@", op);
    }
}

- (void)alert:(NSString *)message {
    WKAlertAction *actionDone = [WKAlertAction actionWithTitle:@"完成" style:WKAlertActionStyleDefault handler:^{
    }];
    WKAlertAction *actionDestruction = [WKAlertAction actionWithTitle:@"毁灭" style:WKAlertActionStyleDestructive handler:^{
    }];
    [self presentAlertControllerWithTitle:@"消息" message:message preferredStyle:WKAlertControllerStyleActionSheet actions:@[actionDone, actionDestruction]];
}

@end
