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

@property Ptr<SVM> svm;
@property int featureLength;

@end



@implementation Classifier

const double EPS = 1e-7;

- (id)initWithSVM:(NSString *)filePath type:(int)type {
    self = [super init];
    self.svm = SVM::load([filePath UTF8String]);
    self.type = type;
    if (self.type == 0) self.featureLength = 64;
    else if (self.type == 1) self.featureLength = 80;
    return self;
}

- (int)classify:(NSArray *)features {
    int length = (int)features.count;
    if (length != self.featureLength) {
        NSLog(@"feature length error");
        return -1;
    }
    float *dataArray = new float[self.featureLength];
    for (int i = 0; i < self.featureLength; i++) dataArray[i] = [features[i] floatValue];
    Mat dataMat = Mat(1, self.featureLength, CV_32F, dataArray);
    float result = self.svm->predict(dataMat);
    delete[] dataArray;
    return (int)(result + EPS);
}

@end
