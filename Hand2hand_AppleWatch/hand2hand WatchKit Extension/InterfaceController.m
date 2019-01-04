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
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *labelTest;
@property (strong, nonatomic) CMMotionManager *manager;

@end


@implementation InterfaceController

NSString * const SENSOR_DATA_GET = @"none";
bool const SENSOR_SHOW_FREQ = false;

// log
bool logging = false;
NSString *buffer = @"";

-(CMMotionManager *) manager {
    if (!_manager) {
        self.manager = [[CMMotionManager alloc] init];
    }
    return _manager;
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    // Configure interface objects here.
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    
    if ([WCSession isSupported]) {
        WCSession* session = [WCSession defaultSession];
        session.delegate = self;
        [session activateSession];
    }
    
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
    
    if (self.manager.isAccelerometerAvailable) {
        [self.manager stopAccelerometerUpdates];
    }
    NSLog(@"bye");
}

- (void)pushAccelerometer {
    if (!self.manager.isAccelerometerAvailable) return;
    self.manager.accelerometerUpdateInterval = 1/100.0;
    __block int freqCnt = 0;
    NSDate *startTime = [NSDate date];
    [self.manager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error) {
        if (error) return;
        CMAcceleration acceleration = accelerometerData.acceleration;
        if (SENSOR_SHOW_FREQ) {
            freqCnt ++;
            float freq = freqCnt / (-[startTime timeIntervalSinceNow]);
            NSLog(@"%f, %f, %f", acceleration.x, acceleration.y, acceleration.z);
            NSLog(@"freqAcc: %f", freq);
        }
    }];
    NSLog(@"Push ready");
}

- (void)setSensorDataGetPull {
    if (self.manager.isAccelerometerAvailable) {
        self.manager.accelerometerUpdateInterval = 1/100.0;
        [self.manager startAccelerometerUpdates];
    }
    [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(getSensorData:) userInfo:nil repeats:YES];
}

- (void)getSensorData:(NSTimer *)timer {
    CMAccelerometerData *data = self.manager.accelerometerData;
    CMAcceleration acceleration = data.acceleration;
    NSLog(@"%f, %f, %f", acceleration.x, acceleration.y, acceleration.z);
}

- (void)changeLogStatus {
    if (logging == true) {
        [self sendMessageToPhone:@"log off"];
        [self.buttonLog setTitle:@"Log/Off"];
        logging = false;
    } else {
        [self sendMessageToPhone:@"log on"];
        [self.buttonLog setTitle:@"Log/On"];
        logging = true;
    }
}

/*- (void)testPath {
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSLog(@"watch documentPath = %@", documentPath);
    
    //[[NSFileManager defaultManager] group]
    
    NSString *sharedPath = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.pcg.hand2hand"] path];
    NSLog(@"watch sharedPath = %@", sharedPath);
    
    NSString *filePath = [sharedPath stringByAppendingPathComponent:@"a.txt"];
    bool ifsuccess = [@"hello" writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if (ifsuccess) NSLog(@"write yes"); else NSLog(@"write no");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *myDirectoryEnumerator = [fileManager enumeratorAtPath:sharedPath];
    NSString *file;
    while((file = [myDirectoryEnumerator nextObject])) {
        NSLog(@"file %@", file);
        if([[file pathExtension] isEqualToString:@"pat"]) {
            //xxx
        }
    }
}*/



/*
 * UI
 */
- (IBAction)doClickButtonTest:(id)sender {
    [self.labelTest setText:@"test"];
    //[self sendToPhone:@{@"message": @"test!"}];
}

- (IBAction)doClickButtonLog:(id)sender {
    [self changeLogStatus];
}



/*
 * communication
 */
// send
- (void)sendToPhone:(NSDictionary *)message {
    WCSession* session = [WCSession defaultSession];
    [session sendMessage:message replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
        // no reply?
    } errorHandler:^(NSError * _Nonnull error) {
        // do nothing
    }];
}

// send message
- (void)sendMessageToPhone:(NSString *)message {
    [self sendToPhone:@{@"message": message}];
}

// recv
- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *,id> *)message replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * __nonnull))replyHandler {
    //[self alert:message[@"message"]];
    NSLog(@"message: %@" , message[@"message"]);
}

// alert
- (void)alert:(NSString *)message {
    WKAlertAction *actionDone = [WKAlertAction actionWithTitle:@"完成" style:WKAlertActionStyleDefault handler:^{
    }];
    WKAlertAction *actionDestruction = [WKAlertAction actionWithTitle:@"毁灭" style:WKAlertActionStyleDestructive handler:^{
    }];
    [self presentAlertControllerWithTitle:@"消息" message:message preferredStyle:WKAlertControllerStyleActionSheet actions:@[actionDone, actionDestruction]];
}

@end
