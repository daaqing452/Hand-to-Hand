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
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelTest;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NSFileManager *fileManager;
@property (strong, nonatomic) WCSession *session;
@property (strong, nonatomic) NSString *documentPath;
@property (strong, nonatomic) NSString *sharedPath;

@end


@implementation InterfaceController

NSString * const SENSOR_DATA_GET = @"push";
bool const SENSOR_SHOW_FREQ = false;

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

- (WCSession *)session {
    if (!_session) {
        if ([WCSession isSupported]) {
            self.session = [WCSession defaultSession];
            self.session.delegate = self;
            [self.session activateSession];
        }
    }
    return _session;
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
    
    if ([SENSOR_DATA_GET isEqualToString:@"push"]) {
        [self pushAccelerometer];
    } else if ([SENSOR_DATA_GET isEqualToString:@"pull"]) {
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
    [self sendMessageToPhone:@"test"];
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
        if (SENSOR_SHOW_FREQ) {
            freqCnt ++;
            float freq = freqCnt / (-[startTime timeIntervalSinceNow]);
            NSLog(@"%f, %f, %f", acceleration.x, acceleration.y, acceleration.z);
            NSLog(@"freqAcc: %f", freq);
        }
        if (logging) {
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
        logging = false;
    } else {
        [self.buttonLog setTitle:@"Log/On"];
        logging = true;
    }
}

- (void)changeLogStatus {
    [self changeLogStatus:!logging];
}



/*
 * file
 */
- (void)writeFile:(NSString *)fileName content:(NSString *)content {
    NSString *filePath = [self.documentPath stringByAppendingPathComponent:fileName];
    bool ifsuccess = [content writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if (ifsuccess) NSLog(@"write file success"); else NSLog(@"write file fail");
}

- (void)showFiles:(NSString *)path {
    NSLog(@"show files: %@", path);
    NSDirectoryEnumerator *myDirectoryEnumerator = [self.fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        NSLog(@"file %@", file);
        if([[file pathExtension] isEqualToString:@"pat"]) {
            //?
        }
    }
}

- (void)deleteFiles:(NSString *)path {
    
}



/*
 * communication
 */
- (void)sendToPhone:(NSDictionary *)dict {
    WCSession* session = [WCSession defaultSession];
    [session sendMessage:dict replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
        // no reply?
    } errorHandler:^(NSError * _Nonnull error) {
        // do nothing
    }];
}

- (void)sendMessageToPhone:(NSString *)message {
    [self sendToPhone:@{@"message": message}];
}

// recv
- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *,id> *)dict replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * __nonnull))replyHandler {
    NSString *op = dict[@"message"];
    if ([op isEqualToString:@"log on"]) {
        [self changeLogStatus:true];
    } else if ([op isEqualToString:@"log off"]) {
        [self changeLogStatus:false];
    } else {
        NSLog(@"%@", op);
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
