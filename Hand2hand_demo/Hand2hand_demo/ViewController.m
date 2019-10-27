//
//  ViewController.m
//  Hand2hand_demo
//
//  Created by Yiqin Lu on 2019/1/31.
//  Copyright © 2019 Yiqin Lu. All rights reserved.
//

#import "ViewController.h"
#import "Classifier.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <WatchConnectivity/WatchConnectivity.h>

#define UILog(format, ...) [self showInfoInUI:[NSString stringWithFormat:(format), ##__VA_ARGS__]]


@interface ViewController () <WCSessionDelegate, CBPeripheralManagerDelegate>

@property (weak, nonatomic) IBOutlet UITextView *textInfo;
@property (weak, nonatomic) IBOutlet UIButton *buttonCalibration;
@property (weak, nonatomic) IBOutlet UIButton *buttonTest;
@property (weak, nonatomic) IBOutlet UIButton *buttonClear;
@property (weak, nonatomic) IBOutlet UIButton *buttonRecognitionOn;
@property (weak, nonatomic) IBOutlet UIButton *buttonRecognitionOff;

@end


@implementation ViewController

WCSession *wcsession;
NSBundle *bundle;
Classifier *classifier;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([WCSession isSupported]) {
        wcsession = [WCSession defaultSession];
        wcsession.delegate = self;
        [wcsession activateSession];
    }
    
    peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"makeBundle" ofType:@"bundle"]];
    
    NSString *fileNameDetectWalking = [bundle pathForResource:@"detect_walking" ofType:@"model"];
    classifier = [[Classifier alloc] initWithSVM:fileNameDetectWalking];
    
    //[self readDataFromBundle:@"log-3-WatchL" ofType:@"txt"];
    
    UILog(@"init finished");
}

- (void)parseCommand:(NSString *)command fromType:(NSString *)fromType {
    if ([command isEqualToString:@"test"]) {
        [self alert:command];
    } else if ([command isEqualToString:@"test watch connectivity"]) {
        [self sendMessageByWatchConnectivity:@"test watch connectivity success"];
        UILog(@"watch connectivity connected");
    } else {
        UILog(@"recv %@: %@", fromType, command);
    }
}

- (float)bytesToFloat:(Byte *)b {
    unsigned int c = ((unsigned int)b[0] << 24) + ((unsigned int)b[1] << 16) + ((unsigned int)b[2] << 8) + (b[3]);
    float *p = (float *)(&c);
    return *p;
}

- (double)fmod: (double)x mod:(double)y {
    return x - (int)(x / y + 1e-7) * y;
}

// recognition
// buffer 8 feature frame (2s)
const int FEATURE_BUFFER = 8;
const double EPS = 1e-7;
const double MAX_ARRIVE_TIME_DIFF = 0.1;
NSMutableArray *featuresLeft[FEATURE_BUFFER], *featuresRight[FEATURE_BUFFER];
double recognizing = false;

- (void)processFrames:(NSData *)data fromType:(NSString *)fromType {
    Byte *bytes = (Byte *)data.bytes;
    Byte ctrl = bytes[0];
    NSMutableArray *features = [[NSMutableArray alloc] init];
    for (int i = 1; i < data.length; i += 4) {
        float value = [self bytesToFloat:bytes + i];
        [features addObject:[NSNumber numberWithFloat:value]];
    }
    float timeArrive = [features[0] floatValue];
    int tidx = (int)([self fmod:timeArrive mod:2.0] * 100 + EPS) / 25;
    NSMutableArray *other;
    if (ctrl == 0) {
        featuresLeft[tidx] = features;
        other = featuresRight[tidx];
        //UILog(@"recv L %f %d", timeArrive, tidx);
    } else if (ctrl == 1) {
        featuresRight[tidx] = features;
        other = featuresLeft[tidx];
        //UILog(@"recv R %f %d", timeArrive, tidx);
    } else {
        UILog(@"recv data from unknown watch");
    }
    if (other != nil) {
        if (fabs(timeArrive - [other[0] floatValue]) < MAX_ARRIVE_TIME_DIFF) {
            [featuresLeft[tidx] removeObjectAtIndex:0];
            [featuresRight[tidx] removeObjectAtIndex:0];
            [featuresLeft[tidx] addObjectsFromArray:featuresRight[tidx]];
            int result = [classifier classify:featuresLeft[tidx]];
            if (result == 1) UILog(@"ans: %d", result);
            featuresLeft[tidx] = nil;
            featuresRight[tidx] = nil;
        } else {
            UILog(@"lr diff: %d %f %f", ctrl, timeArrive, [other[0] floatValue]);
        }
    }
}


//
//  UI
//
- (IBAction)doClickButtonCalibration:(id)sender {
    [self sendMessageByWatchConnectivity:@"start calibration"];
    [self sendMessageByCoreBluetooth:@"start calibration"];
    UILog(@"start calibration");
}

- (IBAction)doClickButtonTest:(id)sender {
    [self sendMessageByCoreBluetooth:[NSString stringWithFormat:@"hello %ld", random() % 100]];
}

- (IBAction)doClickButtonClear:(id)sender {
    [self.textInfo setText:@""];
}

- (IBAction)doClickButtonRecognitionOn:(id)sender {
    recognizing = true;
    [self sendMessageByWatchConnectivity:@"recognition on"];
    [self sendMessageByCoreBluetooth:@"recognition on"];
}

- (IBAction)doClickButtonRecognitionOff:(id)sender {
    recognizing = false;
    [self sendMessageByWatchConnectivity:@"recognition off"];
    [self sendMessageByCoreBluetooth:@"recognition off"];
}

- (void)showInfoInUI:(NSString *)newInfo {
    dispatch_async(dispatch_get_main_queue(),^{
        [self showInfoInUI:newInfo newline:true];
    });
}

- (void)showInfoInUI:(NSString *)newInfo newline:(bool)newline {
    if (newline == true) {
        newInfo = [newInfo stringByAppendingString:@"\n\n"];
    }
    NSString *s = [self.textInfo text];
    s = [s stringByAppendingString:newInfo];
    [self.textInfo setText:s];
}



//
//  file
//
- (NSString *)readDataFromBundle:(NSString *)fileName ofType:(NSString *)ofType {
    NSString *filePath = [bundle pathForResource:fileName ofType:ofType];
    
    NSLog(@"%@", filePath);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *data = [fileManager contentsAtPath:filePath];
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSLog(@"%@", [s substringToIndex:(random() % 10 + 1)]);
    return s;
}



//
//  watch connectivity
//
- (void)sendDataByWatchConnectivity:(NSDictionary *)dict {
    [wcsession sendMessage:dict replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
        // no reply?
    } errorHandler:^(NSError * _Nonnull error) {
        UILog(@"send error %ld: %@", error.code, error);
    }];
}

- (void)sendMessageByWatchConnectivity:(NSString *)message {
    [self sendDataByWatchConnectivity:@{@"message": message}];
}

- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *,id> *)dict replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * __nonnull))replyHandler {
    //replyHandler(@{@"message": @"yes"});
    NSString *message = dict[@"message"];
    if ([message isEqualToString:@"data"]) {
        [self processFrames:dict[@"data"] fromType:@"WC"];
    } else {
        [self parseCommand:message fromType:@"WC"];
    }
}

- (void)session:(nonnull WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
    // do nothing
}


- (void)sessionDidBecomeInactive:(nonnull WCSession *)session {
    // do nothing
}


- (void)sessionDidDeactivate:(nonnull WCSession *)session {
    // do nothing
}

- (void)alert:(NSString *)message {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"消息" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionCentain = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:actionCentain];
    [self presentViewController:alertController animated:YES completion:nil];
}



//
//  core bluetooth
//
NSString *const SERVICE_UUID = @"FEF0";
NSString *const CHARACTERISTIC_UUID_MESSAGE_SEND = @"FEF1";
NSString *const CHARACTERISTIC_UUID_MESSAGE_RECV = @"FEF2";
NSString *const CHARACTERISTIC_UUID_DATA_RECV = @"FEF3";
CBPeripheralManager *peripheralManager;
CBMutableCharacteristic *characteristicMessageSend = nil;

- (void)peripheralManagerDidUpdateState:(nonnull CBPeripheralManager *)peripheral {
    switch (peripheral.state) {
        case CBManagerStatePoweredOn:
            UILog(@"core bluetooth power on");
            [self createServices];
            break;
        case CBManagerStatePoweredOff:
            UILog(@"core bluetooth power off");
            break;
        default:
            break;
    }
}

- (void)createServices {
    characteristicMessageSend = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_MESSAGE_SEND] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    
    CBMutableCharacteristic *characteristicMessageRecv = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_MESSAGE_RECV] properties:CBCharacteristicPropertyWrite | CBCharacteristicPropertyWriteWithoutResponse value:nil permissions:CBAttributePermissionsWriteable];
                                                          
    CBMutableCharacteristic *characteristicDataRecv = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_DATA_RECV] properties:CBCharacteristicPropertyWrite | CBCharacteristicPropertyWriteWithoutResponse value:nil permissions:CBAttributePermissionsWriteable];
    
    CBMutableService *service0 = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:SERVICE_UUID] primary:YES];
    [service0 setCharacteristics:@[characteristicMessageSend, characteristicMessageRecv, characteristicDataRecv]];
    
    [peripheralManager addService:service0];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    [peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:SERVICE_UUID]],CBAdvertisementDataLocalNameKey:@"hand2hand-second-watch"}];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    UILog(@"core bluetooth connected");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests {
    CBATTRequest *request = requests[0];
    if ([[NSString stringWithFormat:@"%@", request.characteristic.UUID] isEqualToString:CHARACTERISTIC_UUID_MESSAGE_RECV]) {
        NSString *command = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
        [self parseCommand:command fromType:@"CB"];
    }
    if ([[NSString stringWithFormat:@"%@", request.characteristic.UUID] isEqualToString:CHARACTERISTIC_UUID_DATA_RECV]) {
        [self processFrames:request.value fromType:@"CB"];
    }
}

- (void)sendMessageByCoreBluetooth:(NSString *)message {
    if (characteristicMessageSend == nil) return;
    [peripheralManager updateValue:[message dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:characteristicMessageSend onSubscribedCentrals:nil];
}

@end


/*
// detect
const double DELIMITER_MAX_BETWEEN_TIME = 0.3;
double delimiterTimeWC = -1, delimiterTimeCB = -1;

// parse command
 else if ([command isEqualToString:@"detect delimiter"]) {
     UILog(@"delimiter %@", fromType);
     double timeNow = [[NSDate date] timeIntervalSince1970];
     if ([fromType isEqualToString:@"WC"]) {
         delimiterTimeWC = timeNow;
     } else if ([fromType isEqualToString:@"CB"]) {
         delimiterTimeCB = timeNow;
     } else {
         UILog(@"detect delimiter error");
     }
     if (fabs(delimiterTimeWC - delimiterTimeCB) < DELIMITER_MAX_BETWEEN_TIME) {
         UILog(@"recognition start");
         recognitionStartTime = timeNow;
         [self doClickButtonRecognitionOn:nil];
     }
 }
 */
