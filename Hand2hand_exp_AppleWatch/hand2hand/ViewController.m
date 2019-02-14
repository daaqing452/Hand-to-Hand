//
//  ViewController.m
//  hand2hand
//
//  Created by Yiqin Lu on 2018/12/26.
//  Copyright © 2018 Yiqin Lu. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <WatchConnectivity/WatchConnectivity.h>

#define UILog(format, ...) [self showInfoInUI:[NSString stringWithFormat:(format), ##__VA_ARGS__]]


@interface ViewController () <WCSessionDelegate, CBPeripheralManagerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *buttonTest;
@property (weak, nonatomic) IBOutlet UIButton *buttonLogOn;
@property (weak, nonatomic) IBOutlet UIButton *buttonLogOff;
@property (weak, nonatomic) IBOutlet UIButton *buttonShowFiles;
@property (weak, nonatomic) IBOutlet UIButton *buttonDeleteFiles;
@property (weak, nonatomic) IBOutlet UIButton *buttonClear;
@property (weak, nonatomic) IBOutlet UITextView *textInfo;
@property (weak, nonatomic) IBOutlet UILabel *labelTest;

@end

@implementation ViewController

WCSession *wcsession;
NSFileManager *fileManager;
NSString *documentPath;
NSString *sharedPath;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    fileManager = [NSFileManager defaultManager];
    documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    sharedPath = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.pcg.hand2hand"] path];
    
    if ([WCSession isSupported]) {
        wcsession = [WCSession defaultSession];
        wcsession.delegate = self;
        [wcsession activateSession];
    }
    
    peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    UILog(@"init finished");
}


//
//  UI
//
- (IBAction)doClickButtonTest:(id)sender {
    [self sendMessageByWatchConnectivity:@"test"];
    [self sendMessageByCoreBluetooth:@"test"];
}

- (IBAction)doClickButtonLogOn:(id)sender {
    [self sendMessageByWatchConnectivity:@"log on"];
    [self sendMessageByCoreBluetooth:@"log on"];
    UILog(@"log on");
}

- (IBAction)doClickButtonLogOff:(id)sender {
    [self sendMessageByWatchConnectivity:@"log off"];
    [self sendMessageByCoreBluetooth:@"log off"];
    UILog(@"log off");
}

- (IBAction)doClickButtonShowFiles:(id)sender {
    [self showFiles:documentPath];
}

- (IBAction)doClickButtonDeleteFiles:(id)sender {
    [self deleteFiles:documentPath];
}

- (IBAction)doClickButtonClear:(id)sender {
    [self.textInfo setText:@""];
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
- (void)writeFile:(NSString *)fileName content:(NSString *)content {
    NSString *filePath = [documentPath stringByAppendingPathComponent:fileName];
    bool ifsuccess = [content writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UILog(@"write file %@: %@", ifsuccess ? @"Y" : @"N", fileName);
}

- (void)showFiles:(NSString *)path {
    UILog(@"show files: %@", path);
    NSDirectoryEnumerator *myDirectoryEnumerator = [fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        if ([[file pathExtension] isEqualToString:@"txt"]) {
            UILog(@"file %@", file);
        }
    }
}

- (void)deleteFiles:(NSString *)path {
    NSDirectoryEnumerator *myDirectoryEnumerator = [fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        NSString *filePath = [documentPath stringByAppendingPathComponent:file];
        bool ifSuccess = [fileManager removeItemAtPath:filePath error:nil];
        UILog(@"delete file %@: %@", ifSuccess ? @"Y" : @"N", file);
    }
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
    NSString *command = dict[@"message"];
    if ([command isEqualToString:@"test"]) {
        [self alert:command];
    } else if ([command isEqualToString:@"test watch connectivity"]) {
        [self sendMessageByWatchConnectivity:@"test watch connectivity success"];
        UILog(@"watch connectivity connected");
    } else {
        UILog(@"recv from WC: %@", command);
    }
}

- (void)session:(nonnull WCSession *)session didReceiveFile:(nonnull WCSessionFile *)file {
    NSError *error = nil;
    NSString *filePath = [[file fileURL] path];
    NSString *fileName = [filePath lastPathComponent];
    bool ifSuccess = [fileManager copyItemAtPath:filePath toPath:[documentPath stringByAppendingPathComponent:fileName] error:&error];
    UILog(@"recv file %@: %@", ifSuccess ? @"Y" : @"N", fileName);
    if (!ifSuccess) {
        UILog(@"error %@", error);
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
NSString *const CHARACTERISTIC_UUID_NOTIFY = @"FEF1";
NSString *const CHARACTERISTIC_UUID_READ_WRITE = @"FEF2";
CBPeripheralManager *peripheralManager;
CBMutableCharacteristic *sendCharacteristic;

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
    CBMutableCharacteristic *characteristicNotify = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_NOTIFY] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    
    CBMutableCharacteristic *characteristicReadWrite = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:CHARACTERISTIC_UUID_READ_WRITE] properties:CBCharacteristicPropertyRead | CBCharacteristicPropertyWrite | CBCharacteristicPropertyWriteWithoutResponse value:nil permissions:CBAttributePermissionsReadable | CBAttributePermissionsWriteable];
    
    sendCharacteristic = characteristicNotify;
    
    CBMutableService *service0 = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:SERVICE_UUID] primary:YES];
    [service0 setCharacteristics:@[characteristicNotify, characteristicReadWrite]];
    
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
    NSString *message = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
    UILog(@"recv from CB: %@", message);
}

- (void)sendMessageByCoreBluetooth:(NSString *)message {
    [peripheralManager updateValue:[message dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:sendCharacteristic onSubscribedCentrals:nil];
}


@end
