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
#import <AVFoundation/AVFoundation.h>

#define UILog(format, ...) [self showInfoInUI:[NSString stringWithFormat:(format), ##__VA_ARGS__]]


@interface ViewController () <WCSessionDelegate, CBPeripheralManagerDelegate>

@property (weak, nonatomic) IBOutlet UITextView *textInfo;
@property (weak, nonatomic) IBOutlet UIButton *buttonCalibration;
@property (weak, nonatomic) IBOutlet UIButton *buttonRecognition;
@property (weak, nonatomic) IBOutlet UIButton *buttonClear;
@property (weak, nonatomic) IBOutlet UIButton *buttonMode;
@property (weak, nonatomic) IBOutlet UIButton *buttonExperiment;
@property (weak, nonatomic) IBOutlet UIButton *buttonExperimentCommand;
@property (weak, nonatomic) IBOutlet UIButton *buttonFalseUser;
@property (weak, nonatomic) IBOutlet UIButton *buttonFalseNegative;

@end



@implementation ViewController

WCSession *wcsession;
NSBundle *bundle;
Classifier *detector, *recognizerStationay, *recognizerWalking, *recognizerRunning;
NSFileManager *fileManager;
NSString *documentPath;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([WCSession isSupported]) {
        wcsession = [WCSession defaultSession];
        wcsession.delegate = self;
        [wcsession activateSession];
    }
    
    peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    
    bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"makeBundle" ofType:@"bundle"]];
    detector = [[Classifier alloc] initWithSVM:[bundle pathForResource:@"detect_walking_sta" ofType:@"model"]];
    recognizerStationay = [[Classifier alloc] initWithSVM:[bundle pathForResource:@"opencv_gesture_20191103" ofType:@"model"]];
    recognizerWalking = [[Classifier alloc] initWithSVM:[bundle pathForResource:@"recognition_walking" ofType:@"model"]];
    recognizerRunning = [[Classifier alloc] initWithSVM:[bundle pathForResource:@"recognition_walking" ofType:@"model"]];
    //[self readDataFromBundle:@"log-3-WatchL" ofType:@"txt"];
    
    fileManager = [NSFileManager defaultManager];
    documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    [self initExperiment];
    
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



// recognition
// buffer 20 feature frame (5s)
const int FEATURE_BUFFER = 20;
const double EPS = 1e-7;
const double MAX_ARRIVE_TIME_DIFF = 0.1;
NSMutableArray *featuresLeft[FEATURE_BUFFER], *featuresRight[FEATURE_BUFFER];
double recognizing = false;

- (float)bytesToFloat:(Byte *)b {
    unsigned int c = ((unsigned int)b[0] << 24) + ((unsigned int)b[1] << 16) + ((unsigned int)b[2] << 8) + (b[3]);
    float *p = (float *)(&c);
    return *p;
}

- (double)fmod: (double)x mod:(double)y {
    return x - (int)(x / y + 1e-7) * y;
}

- (void)processFrames:(NSData *)data fromType:(NSString *)fromType {
    Byte *bytes = (Byte *)data.bytes;
    Byte ctrl = bytes[0];
    NSMutableArray *features = [[NSMutableArray alloc] init];
    for (int i = 1; i < data.length; i += 4) {
        float value = [self bytesToFloat:bytes + i];
        [features addObject:[NSNumber numberWithFloat:value]];
    }
    float timeArrive = [features[0] floatValue];
    int tidx = (int)([self fmod:timeArrive mod:FEATURE_BUFFER / 4] * 100 + EPS) / 25;
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
            int resD = [detector classify:featuresLeft[tidx]], resR = -1;
            if (resD != 0) {
                Classifier *recognizer;
                if (mode == M_Stationary) recognizer = recognizerStationay;
                else if (mode == M_Walking) recognizer = recognizerWalking;
                else if (mode == M_Running) recognizer = recognizerRunning;
                resR = [recognizer classify:featuresLeft[tidx]];
                UILog(@"ans: %d", resR);
                if (!experimenting) [self speakText:[NSString stringWithFormat:@"%d", resR] language:@"Chinese"];
            }
            if (experimenting) [self feed:resR];
            featuresLeft[tidx] = nil;
            featuresRight[tidx] = nil;
        } else {
            NSLog(@"lr diff: %d %f %f", ctrl, timeArrive, [other[0] floatValue]);
        }
    }
}



//  experiment
// ['IxP', 'IxB', 'IxI', 'IxFU', 'FUxFU', 'FDxFU', 'PxFU', 'FDxP']
enum Mode { M_Stationary, M_Walking, M_Running } mode = M_Stationary;
enum TaskState { TS_Normal, TS_PlayingMusic, TS_ReadingMessage } taskState;
enum Command { C_AnswerCall, C_RejectCall, C_NextMusic, C_PrevMusic, C_PlayPause, C_ReadMessage, C_DeleteMessage, C_ReplyMessage } nowCommand;
NSArray *predStationary, *predMoving;
NSDictionary *mapping;
NSMutableArray *feedArray;

bool experimenting = false;
int falseUser = 0;
int falsePositive = 0;
int falseNegative = 0;
int falseRecognition = 0;

NSMutableArray *musicPaths;
int musicIndex;
AVAudioPlayer *nowPlayer;

- (void)initExperiment {
    predStationary = @[@"IxP", @"IxB", @"IxI", @"IxFU", @"FUxFU", @"FDxFU", @"PxFU", @"FDxP"];
    predMoving = @[@"IxP", @"IxB", @"FDxP", @"PxFU", @"FDxFU"];
    mapping = @{@"IxP":[NSNumber numberWithInt:C_AnswerCall], @"IxB":[NSNumber numberWithInt:C_RejectCall], @"FDxP":[NSNumber numberWithInt:C_NextMusic], @"PxFU":[NSNumber numberWithInt:C_PrevMusic], @"FDxFU":[NSNumber numberWithInt:C_PlayPause], @"IxFU":[NSNumber numberWithInt:C_ReadMessage], @"IxI":[NSNumber numberWithInt:C_DeleteMessage], @"FUxFU":[NSNumber numberWithInt:C_ReplyMessage]};

    NSString *musicDirPath = [bundle pathForResource:@"bensound" ofType:@""];
    NSDirectoryEnumerator *myDirectoryEnumerator = [fileManager enumeratorAtPath:musicDirPath];
    musicPaths = [[NSMutableArray alloc] init];
    NSString *file;
    while ((file = [myDirectoryEnumerator nextObject])) {
        if ([[file pathExtension] isEqualToString:@"mp3"]) {
            NSURL *url = [bundle URLForResource:[NSString stringWithFormat:@"bensound/%@", file] withExtension:@""];
            [musicPaths addObject:url];
        }
    }
}

- (void)experimentStart {
    taskState = TS_Normal;
    musicIndex = 0;
    [self musicChange:0];
    falseUser = falsePositive = falseNegative = falseRecognition = 0;
    
    [self.buttonExperiment setTitle:@"Exp. Start" forState:UIControlStateNormal];
    experimenting = true;
}

- (void)experimentEnd {
    [self.buttonExperiment setTitle:@"Exp. End" forState:UIControlStateNormal];
    experimenting = false;
}

- (void)nextCommand {
    if (taskState == TS_Normal) {
        int r = arc4random() % (mode == M_Stationary ? 50 : 30);
        if (r < 10) nowCommand = C_AnswerCall;
        else if (r < 20) nowCommand = C_RejectCall;
        else if (r < 30) nowCommand = C_PlayPause;
        else if (r < 40) nowCommand = C_ReadMessage;
        else if (r < 50) nowCommand = C_DeleteMessage;
    } else if (taskState == TS_PlayingMusic) {
        int r = arc4random() % 50;
        if (r < 10) nowCommand = C_PlayPause;
        else if (r < 30) nowCommand = C_PrevMusic;
        else if (r < 50) nowCommand = C_NextMusic;
    } else if (taskState == TS_ReadingMessage) {
        int r = arc4random() % 50;
        if (r < 20) nowCommand = C_ReplyMessage;
        else if (r < 30) nowCommand = C_AnswerCall;
        else if (r < 40) nowCommand = C_RejectCall;
        else if (r < 50) nowCommand = C_PlayPause;
    }
    [self issueStimuli:nowCommand];
}

- (void)receiveCommand:(int)command {
    if (nowCommand == -1) {
        falsePositive++;
        UILog(@"False Positive");
    } else if (command != nowCommand) {
        falseRecognition++;
        UILog(@"False Recognition");
    } else {
        [self issueFeedback:command];
        nowCommand = -1;
    }
}

- (void)feed:(int)resR {
    if (!experimenting) return;
    if (resR == -1) {
        if (feedArray.count > 0) {
            bool flag = false;
            for (int i = 0; i < feedArray.count; i++) {
                int command = [feedArray[i] intValue];
                if (command == nowCommand) flag = true;
            }
            int command = flag ? nowCommand : [feedArray[0] intValue];
            [self receiveCommand:command];
        }
        [feedArray removeAllObjects];
    } else {
        int command = -1;
        if (mode == M_Stationary) {
            command = [(NSNumber *)[mapping valueForKey:predStationary[resR]] intValue];
        } else {
            command = [(NSNumber *)[mapping valueForKey:predMoving[resR]] intValue];
        }
        [feedArray addObject:[NSNumber numberWithInt:command]];
    }
}

- (void)issueStimuli:(int)command {
    NSArray *nameList = @[@"张子豪", @"郭英超", @"陈远杰", @"马玉涛", @"周翔", @"陈佳颖", @"王雨涵", @"吴哲宇", @"陶红杰", @"陈阳"];
    if (command == C_AnswerCall) {
        NSString *name = nameList[arc4random() % nameList.count];
        [self speakText:[NSString stringWithFormat:@"来电提示：%@", name] language:@"Chinese"];
    } else if (command == C_RejectCall) {
        [self speakText:@"来电提示：未知号码" language:@"Chinese"];
    } else if (command == C_NextMusic) {
        [self speakText:@"下一首音乐" language:@"Chinese"];
    } else if (command == C_PrevMusic) {
        [self speakText:@"上一首音乐" language:@"Chinese"];
    } else if (command == C_PlayPause) {
        [self speakText:(taskState == TS_PlayingMusic ? @"暂停音乐" : @"播放音乐") language:@"Chinese"];
    } else if (command == C_ReadMessage) {
        NSString *name = nameList[arc4random() % nameList.count];
        [self speakText:[NSString stringWithFormat:@"新消息提示：%@", name] language:@"Chinese"];
    } else if (command == C_DeleteMessage) {
        [self speakText:@"新消息提示：未知号码" language:@"Chinese"];
    } else if (command == C_ReplyMessage) {
        [self speakText:@"回复语音" language:@"Chinese"];
    }
}

- (void)issueFeedback:(int)command {
    if (command == C_AnswerCall) {
        [self speakText:@"接听成功" language:@"Chinese"];
        taskState = TS_Normal;
    } else if (command == C_RejectCall) {
        [self speakText:@"已挂断" language:@"Chinese"];
        taskState = TS_Normal;
    } else if (command == C_NextMusic) {
        [self musicChange:1];
        taskState = TS_Normal;
    } else if (command == C_PrevMusic) {
        [self musicChange:-1];
        taskState = TS_Normal;
    } else if (command == C_PlayPause) {
        if (taskState == TS_PlayingMusic) {
            [nowPlayer pause];
            taskState = TS_Normal;
        } else {
            [nowPlayer play];
            taskState = TS_PlayingMusic;
        }
    } else if (command == C_ReadMessage) {
        NSArray *messageList = @[@"上次多亏了你帮我度过难关", @"在干嘛，吃饭了吗", @"周末一起去故宫玩怎么样", @"记住我说的，凡事以自己为先", @"你今年多大啦", @"你昨晚干嘛去了", @"第三章第四题怎么做啊", @"最近手头有点紧，能不能借我点钱", @"我看到你朋友圈了，照片真好看", @"你看过变形金刚吗"];
        NSString *message = messageList[arc4random() % [messageList count]];
        [self speakText:message language:@"Chinese"];
        taskState = TS_ReadingMessage;
    } else if (command == C_DeleteMessage) {
        [self speakText:@"删除成功" language:@"Chinese"];
        taskState = TS_Normal;
    } else if (command == C_ReplyMessage) {
        [self speakText:@"语音开启请回复" language:@"Chinese"];
        taskState = TS_Normal;
    }
}

- (void)musicChange:(int)delta {
    [nowPlayer stop];
    nowPlayer.currentTime = 0;
    musicIndex = (int)(musicIndex + musicPaths.count + delta) % musicPaths.count;
    NSURL *url = (NSURL *)[musicPaths objectAtIndex:musicIndex];
    nowPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
}



//
//  UI
//
- (IBAction)doClickButtonCalibration:(id)sender {
    [self sendMessageByWatchConnectivity:@"start calibration"];
    [self sendMessageByCoreBluetooth:@"start calibration"];
    UILog(@"start calibration");
}

- (IBAction)doClickButtonRecognition:(id)sender {
    if (recognizing) {
        [self sendMessageByWatchConnectivity:@"recognition off"];
        [self sendMessageByCoreBluetooth:@"recognition off"];
        [self.buttonRecognition setTitle:@"Rec. Off" forState:UIControlStateNormal];
        recognizing = false;
    } else {
        [self sendMessageByWatchConnectivity:@"recognition on"];
        [self sendMessageByCoreBluetooth:@"recognition on"];
        [self.buttonRecognition setTitle:@"Rec. On" forState:UIControlStateNormal];
        recognizing = true;
    }
}

- (IBAction)doClickButtonClear:(id)sender {
    [self.textInfo setText:@""];
}

- (IBAction)doClickButtonMode:(id)sender {
    if (mode == M_Stationary) {
        mode = M_Walking;
        [self.buttonMode setTitle:@"Walking" forState:UIControlStateNormal];
    } else if (mode == M_Walking) {
        mode = M_Running;
        [self.buttonMode setTitle:@"Running" forState:UIControlStateNormal];
    } else if (mode == M_Running) {
        mode = M_Stationary;
        [self.buttonMode setTitle:@"Stationary" forState:UIControlStateNormal];
    }
}

- (IBAction)doClickButtonExperiment:(id)sender {
    if (experimenting) {
        [self experimentEnd];
    } else {
        [self experimentStart];
    }
}

- (IBAction)doClickButtonExperimentCommand:(id)sender {
    [self speakText:@"0" language:@"Chinese"];
}

- (IBAction)doClickButtonFalseUser:(id)sender {
    if (experimenting) {
        falseUser++;
        UILog(@"False User %d", falseUser);
    }
}

- (IBAction)doClickButtonFalseNegative:(id)sender {
    if (experimenting) {
        falseNegative++;
        UILog(@"False Negative %d", falseNegative);
    }
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
//  voice
//
- (void)speakText:(NSString *)text language:(NSString *)language {
    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:text];
    utterance.pitchMultiplier = 0.8;
    if ([language isEqualToString:@"Chinese"]) {
        AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
        utterance.voice = voice;
    }
    AVSpeechSynthesizer *synthesizer = [[AVSpeechSynthesizer alloc] init];
    [synthesizer speakUtterance:utterance];
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
