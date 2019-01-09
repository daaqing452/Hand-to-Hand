//
//  ViewController.m
//  hand2hand
//
//  Created by 鲁逸沁 on 2018/12/26.
//  Copyright © 2018年 鲁逸沁. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *buttonTest;
@property (weak, nonatomic) IBOutlet UIButton *buttonLogOn;
@property (weak, nonatomic) IBOutlet UIButton *buttonLogOff;
@property (weak, nonatomic) IBOutlet UIButton *buttonShowFiles;
@property (weak, nonatomic) IBOutlet UITextView *textInfo;
@property (weak, nonatomic) IBOutlet UILabel *labelTest;

@property (strong, nonatomic) NSFileManager *fileManager;
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

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    if ([WCSession isSupported]) {
        self.session = [WCSession defaultSession];
        self.session.delegate = self;
        [self.session activateSession];
    }
}



/*
 * UI
 */
- (IBAction)doClickButtonTest:(id)sender {
    [self sendMessage:@"test"];
    [self appendInfo:@"test"];
}

- (IBAction)doClickButtonLogOn:(id)sender {
    [self sendMessage:@"log on"];
}

- (IBAction)doClickButtonLogOff:(id)sender {
    [self sendMessage:@"log off"];
}

- (IBAction)doClickButtonShowFiles:(id)sender {
    [self showFiles:self.documentPath];
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
    if (ifsuccess) NSLog(@"write file success"); else NSLog(@"write file fail");
}

- (void)showFiles:(NSString *)path {
    [self appendInfo:[NSString stringWithFormat:@"show files: %@", path]];
    NSDirectoryEnumerator *myDirectoryEnumerator = [self.fileManager enumeratorAtPath:path];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        [self appendInfo:[NSString stringWithFormat:@"file %@", file]];
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
    [self appendInfo:@"recv " newline:false];
    [self appendInfo:[[file fileURL] path]];
    NSError *error = nil;
    bool ifSuccess = [self.fileManager copyItemAtPath:[[file fileURL] path] toPath:[self.documentPath stringByAppendingPathComponent:@"a.txt"] error:&error];
    [self appendInfo:(ifSuccess ? @"success" : @"fail")];
    [self appendInfo:[NSString stringWithFormat:@"error %@", error]];
}

- (void)alert:(NSString *)message {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"消息" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionCentain = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:actionCentain];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
