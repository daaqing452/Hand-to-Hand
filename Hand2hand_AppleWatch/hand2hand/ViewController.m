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
@property (weak, nonatomic) IBOutlet UITextView *textInfo;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    if ([WCSession isSupported]) {
        WCSession* session = [WCSession defaultSession];
        session.delegate = self;
        [session activateSession];
    }
    
    //[self testPath];
}

- (void)testPath {
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *sharedPath = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.pcg.hand2hand"] path];
    
    [self appendInfo:@"phone documentPath = "];
    [self appendInfo:documentPath newline:true];
    [self appendInfo:@"phone sharedPath = "];
    [self appendInfo:sharedPath newline:true];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *myDirectoryEnumerator = [fileManager enumeratorAtPath:sharedPath];
    NSString *file;
    while((file = [myDirectoryEnumerator nextObject])) {
        [self appendInfo:@"file "];
        [self appendInfo:file newline:true];
    }
}



/*
 * UI
 */
- (IBAction)doClickButton:(id)sender {
    [self sendToRemote:@{@"message": @"test"}];
}

- (void)appendInfo:(NSString *)newInfo {
    NSString *s = [self.textInfo text];
    s = [s stringByAppendingString:newInfo];
    [self.textInfo setText:s];
}

- (void)appendInfo:(NSString *)newInfo newline:(bool)newline {
    if (newline == true) {
        newInfo = [newInfo stringByAppendingString:@"\n"];
    }
    [self appendInfo:newInfo];
}



/*
 * communication
 */
// send
- (void)sendToRemote:(NSDictionary *)message {
    WCSession* session = [WCSession defaultSession];
    [session sendMessage:message replyHandler:^(NSDictionary<NSString *,id> * _Nonnull replyMessage) {
        // no reply?
    } errorHandler:^(NSError * _Nonnull error) {
        // do nothing
    }];
}

// send message
- (void)sendMessageToRemote:(NSString *)message {
    [self sendToRemote:@{@"message": message}];
}

// recv
- (void)session:(nonnull WCSession *)session didReceiveMessage:(nonnull NSDictionary<NSString *,id> *)message replyHandler:(nonnull void (^)(NSDictionary<NSString *,id> * __nonnull))replyHandler {
    [self alert:message[@"message"]];
}

// alert
- (void)alert:(NSString *)message {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"消息" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionCentain = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:actionCentain];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
