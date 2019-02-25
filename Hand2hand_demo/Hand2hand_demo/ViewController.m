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
NSMutableArray *featuresLeft = nil, *featuresRight = nil;

// detect & recognition
const double DELIMITER_MAX_BETWEEN_TIME = 0.3;
const double RECOGNITION_EXPIRE_TIME = 3.0;
double delimiterDateWC = -1, delimiterDateCB = -1;
double recognitionStartDate = -1;
double recognizing = false;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([WCSession isSupported]) {
        wcsession = [WCSession defaultSession];
        wcsession.delegate = self;
        [wcsession activateSession];
    }
    
    peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"MakeBuddle" ofType:@"bundle"]];
    
    NSString *fileName = [bundle pathForResource:@"opencv" ofType:@"model"];
    classifier = [[Classifier alloc] initWithSVM:fileName];
    
    [self readDataFromBundle:@"log-3-WatchL" ofType:@"txt"];
    
    UILog(@"init finished");
}

- (void)parseCommand:(NSString *)command fromType:(NSString *)fromType {
    if ([command isEqualToString:@"test"]) {
        [self alert:command];
    } else if ([command isEqualToString:@"test watch connectivity"]) {
        [self sendMessageByWatchConnectivity:@"test watch connectivity success"];
        UILog(@"watch connectivity connected");
    } else if ([command isEqualToString:@"detect delimiter"]) {
        UILog(@"delimiter %@", fromType);
        double dateNow = [[NSDate date] timeIntervalSince1970];
        if ([fromType isEqualToString:@"WC"]) {
            delimiterDateWC = dateNow;
        } else if ([fromType isEqualToString:@"CB"]) {
            delimiterDateCB = dateNow;
        } else {
            UILog(@"detect delimiter error");
        }
        if (fabs(delimiterDateWC - delimiterDateCB) < DELIMITER_MAX_BETWEEN_TIME) {
            UILog(@"recognition start");
            recognitionStartDate = dateNow;
            [self doClickButtonRecognitionOn:nil];
        }
    } else {
        UILog(@"recv %@: %@", fromType, command);
    }
}

- (void)processFrames:(NSData *)data fromType:(NSString *)fromType {
    NSMutableArray *features = [[NSMutableArray alloc] init];
    Byte *bytes = (Byte *)data.bytes;
    unsigned long length = data.length;
    for (int i = 1; i < length; i += 2) {
        short b0 = bytes[i + 0];
        short b1 = bytes[i + 1];
        short shortValue = (b0 << 8) | b1;
        float value = shortValue / 1000.0;
        [features addObject:[NSNumber numberWithFloat:value]];
    }
    if (bytes[0] == 0) {
        featuresLeft = features;
    } else if (bytes[0] == 1) {
        featuresRight = features;
    } else {
        UILog(@"recv data from unknown watch");
    }
    if (featuresLeft != nil && featuresRight != nil) {
        [featuresLeft addObjectsFromArray:featuresRight];
        int result = [classifier classify:featuresLeft];
        //UILog(@"ans: %d", result);
        NSLog(@"ans: %d", result);
        featuresLeft = nil;
        featuresRight = nil;
    }
    
    // expire
    double dateNow = [[NSDate date] timeIntervalSince1970];
    if (recognizing && dateNow - recognitionStartDate > RECOGNITION_EXPIRE_TIME) {
        UILog(@"recognition expire");
        [self doClickButtonRecognitionOff:nil];
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
    if ([message isEqualToString:@"features"]) {
        [self processFrames:dict[@"data"] fromType:@"watch connectivity"];
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
        [self processFrames:request.value fromType:@"core bluetooth"];
    }
}

- (void)sendMessageByCoreBluetooth:(NSString *)message {
    if (characteristicMessageSend == nil) return;
    [peripheralManager updateValue:[message dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:characteristicMessageSend onSubscribedCentrals:nil];
}

@end
