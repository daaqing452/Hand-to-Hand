//
//  ViewController.m
//  hand2hand
//
//  Created by 鲁逸沁 on 2018/12/26.
//  Copyright © 2018年 鲁逸沁. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <WatchConnectivity/WatchConnectivity.h>

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



/*
 * UI
 */
- (IBAction)doClickButtonTest:(id)sender {
    [self sendMessage:@"test"];
    [self broadcastMessage:@"test"];
    [self appendInfo:@"test"];
}

- (IBAction)doClickButtonLogOn:(id)sender {
    [self sendMessage:@"log on"];
    [self broadcastMessage:@"log on"];
    [self appendInfo:@"log on"];
}

- (IBAction)doClickButtonLogOff:(id)sender {
    [self sendMessage:@"log off"];
    [self broadcastMessage:@"log off"];
    [self appendInfo:@"log off"];
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

- (void)appendInfo:(NSString *)newInfo {
    [self appendInfo:newInfo newline:true];
}

- (void)appendInfo:(NSString *)newInfo newline:(bool)newline {
    if (newline == true) {
        newInfo = [newInfo stringByAppendingString:@"\n\n"];
    }
    NSString *s = [self.textInfo text];
    s = [s stringByAppendingString:newInfo];
    [self.textInfo setText:s];
}



/*
 * file
 */
- (void)writeFile:(NSString *)fileName content:(NSString *)content {
    NSString *filePath = [self.documentPath stringByAppendingPathComponent:fileName];
    bool ifsuccess = [content writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self appendInfo:[NSString stringWithFormat:@"write file %@: %@", ifsuccess ? @"Y" : @"N", fileName]];
}

- (void)showFiles:(NSString *)path {
    [self appendInfo:[NSString stringWithFormat:@"show files: %@", path]];
    NSDirectoryEnumerator *myDirectoryEnumerator = [self.fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        [self appendInfo:[NSString stringWithFormat:@"file %@", file]];
    }
}

- (void)deleteFiles:(NSString *)path {
    NSDirectoryEnumerator *myDirectoryEnumerator = [self.fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        NSString *filePath = [self.documentPath stringByAppendingPathComponent:file];
        bool ifSuccess = [self.fileManager removeItemAtPath:filePath error:nil];
        [self appendInfo:[NSString stringWithFormat:@"delete file %@: %@", (ifSuccess ? @"Y" : @"N"), file]];
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

- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *,id> *)dict replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * __nonnull))replyHandler {
    NSString *op = dict[@"message"];
    [self alert:op];
}

- (void)session:(nonnull WCSession *)session didReceiveFile:(nonnull WCSessionFile *)file {
    NSError *error = nil;
    NSString *filePath = [[file fileURL] path];
    NSString *fileName = [filePath lastPathComponent];
    bool ifSuccess = [self.fileManager copyItemAtPath:filePath toPath:[self.documentPath stringByAppendingPathComponent:fileName] error:&error];
    [self appendInfo:[NSString stringWithFormat:@"recv file %@: %@", ifSuccess ? @"Y" : @"N", fileName]];
    if (!ifSuccess) {
        [self appendInfo:[NSString stringWithFormat:@"error %@", error]];
    }
}

- (void)alert:(NSString *)message {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"消息" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionCentain = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:actionCentain];
    [self presentViewController:alertController animated:YES completion:nil];
}



/*
 * bluetooth
 */
NSString *const SERVICE_UUID = @"FEF0";
NSString *const CHARACTERISTIC_UUID_NOTIFY = @"FEF1";
NSString *const CHARACTERISTIC_UUID_READ_WRITE = @"FEF2";
CBMutableCharacteristic *sendCharacteristic;

- (void)peripheralManagerDidUpdateState:(nonnull CBPeripheralManager *)peripheral {
    switch (peripheral.state) {
        case CBManagerStatePoweredOn:
            [self appendInfo:@"bluetooth power on"];
            [self createServices];
            break;
        case CBManagerStatePoweredOff:
            [self appendInfo:@"bluetooth power off"];
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
    [self appendInfo:@"broadcast serivce"];
    [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey: @[[CBUUID UUIDWithString:SERVICE_UUID]],CBAdvertisementDataLocalNameKey:@"hand2hand-second-watch"}];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    [self appendInfo:@"central subscribed!"];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests {
    CBATTRequest *request = requests[0];
    NSString *message = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
    [self appendInfo:[NSString stringWithFormat:@"cbrecv: %@", message]];
}

- (void)broadcastMessage:(NSString *)message {
    [self.peripheralManager updateValue:[message dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:sendCharacteristic onSubscribedCentrals:nil];
}

@end
