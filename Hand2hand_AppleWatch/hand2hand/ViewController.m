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

@interface ViewController () <CBPeripheralManagerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *buttonTest;
@property (weak, nonatomic) IBOutlet UIButton *buttonLogOn;
@property (weak, nonatomic) IBOutlet UIButton *buttonLogOff;
@property (weak, nonatomic) IBOutlet UIButton *buttonShowFiles;
@property (weak, nonatomic) IBOutlet UIButton *buttonDeleteFiles;
@property (weak, nonatomic) IBOutlet UIButton *buttonClear;
@property (weak, nonatomic) IBOutlet UITextView *textInfo;
@property (weak, nonatomic) IBOutlet UILabel *labelTest;

@property (strong, nonatomic) NSFileManager *fileManager;
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) WCSession *session;
@property (strong, nonatomic) NSString *documentPath;
@property (strong, nonatomic) NSString *sharedPath;

@end

@implementation ViewController

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

NSMutableArray<CBPeripheral*> *devices;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    if ([WCSession isSupported]) {
        self.session = [WCSession defaultSession];
        self.session.delegate = self;
        [self.session activateSession];
    }
    
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}



//
//  UI
//
- (IBAction)doClickButtonTest:(id)sender {
    [self sendMessageByWatchConnectivity:@"test"];
    [self sendMessageByCoreBluetooth:@"test"];
    UILog(@"test");
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
    [self showFiles:self.documentPath];
}

- (IBAction)doClickButtonDeleteFiles:(id)sender {
    [self deleteFiles:self.documentPath];
}

- (IBAction)doClickButtonClear:(id)sender {
    [self.textInfo setText:@""];
}

- (void)showInfoInUI:(NSString *)newInfo {
    [self showInfoInUI:newInfo newline:true];
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
    NSString *filePath = [self.documentPath stringByAppendingPathComponent:fileName];
    bool ifsuccess = [content writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UILog(@"write file %@: %@", ifsuccess ? @"Y" : @"N", fileName);
}

- (void)showFiles:(NSString *)path {
    UILog(@"show files: %@", path);
    NSDirectoryEnumerator *myDirectoryEnumerator = [self.fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        if ([[file pathExtension] isEqualToString:@"txt"]) {
            UILog(@"file %@", file);
        }
    }
}

- (void)deleteFiles:(NSString *)path {
    NSDirectoryEnumerator *myDirectoryEnumerator = [self.fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        NSString *filePath = [self.documentPath stringByAppendingPathComponent:file];
        bool ifSuccess = [self.fileManager removeItemAtPath:filePath error:nil];
        UILog(@"delete file %@: %@", ifSuccess ? @"Y" : @"N", file);
    }
}



//
//  watch connectivity
//
- (void)sendDataByWatchConnectivity:(NSDictionary *)dict {
    [self.session sendMessage:dict replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
        // no reply?
    } errorHandler:^(NSError * _Nonnull error) {
        // do nothing
    }];
}

- (void)sendMessageByWatchConnectivity:(NSString *)message {
    [self sendDataByWatchConnectivity:@{@"message": message}];
}

- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *,id> *)dict replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * __nonnull))replyHandler {
    NSString *command = dict[@"message"];
    if ([command isEqualToString:@"test"]) {
        [self alert:command];
    } else if ([command isEqualToString:@"test watch connectivity"]) {
        // ignore
    } else {
        UILog(@"recv from WC: %@", command);
    }
}

- (void)session:(nonnull WCSession *)session didReceiveFile:(nonnull WCSessionFile *)file {
    NSError *error = nil;
    NSString *filePath = [[file fileURL] path];
    NSString *fileName = [filePath lastPathComponent];
    bool ifSuccess = [self.fileManager copyItemAtPath:filePath toPath:[self.documentPath stringByAppendingPathComponent:fileName] error:&error];
    UILog(@"recv file %@: %@", ifSuccess ? @"Y" : @"N", fileName);
    if (!ifSuccess) {
        UILog(@"error %@", error);
    }
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
    
    [self.peripheralManager addService:service0];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:SERVICE_UUID]],CBAdvertisementDataLocalNameKey:@"hand2hand-second-watch"}];
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
    [self.peripheralManager updateValue:[message dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:sendCharacteristic onSubscribedCentrals:nil];
}


@end
