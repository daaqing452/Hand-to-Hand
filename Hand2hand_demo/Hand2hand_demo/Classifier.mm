//
//  MachineLearning.m
//  Hand2hand_demo
//
//  Created by Yiqin Lu on 2019/1/31.
//  Copyright © 2019 Yiqin Lu. All rights reserved.
//

#import "Classifier.h"

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
using namespace cv;
using namespace cv::ml;
#endif



@interface Classifier()

@end



@implementation Classifier

const int FEATURES_LENGTH = 64;

Ptr<SVM> svm;

- (id)initWithSVM:(NSString *)filePath {
    self = [super init];
    svm = SVM::load([filePath UTF8String]);
    return self;
}

- (int)classify:(NSArray *)features {
    int length = (int)features.count;
    if (length != FEATURES_LENGTH) {
        NSLog(@"feature length error");
        return -1;
    }
    float *dataArray = new float[FEATURES_LENGTH];
    for (int i = 0; i < FEATURES_LENGTH; i++) dataArray[i] = [features[i] floatValue];
    Mat dataMat = Mat(1, FEATURES_LENGTH, CV_32F, dataArray);
    float result = svm->predict(dataMat);
    delete[] dataArray;
    return result;
}

@end
