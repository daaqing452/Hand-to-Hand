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

Ptr<SVM> svm;

- (id)initWithSVM:(NSString *)filePath {
    self = [super init];
    svm = SVM::load([filePath UTF8String]);
    
    /*float trainDataC[][2] = {{0,0},{0,1},{1,0},{1,1}};
    Mat trainData(9, 2, CV_32F, trainDataC);
    for (int i = 0; i < 9; i++) {
        Mat nowData = trainData(Range(i,i+1), Range().all());
        float result = svm->predict(nowData);
        NSLog(@"%d: %f", i, result);
    }*/
    
    /*Ptr<SVM> svm = SVM::create();
    svm->setKernel(SVM::RBF);
    svm->setType(SVM::NU_SVC);*/
    
    return self;
}

- (int)classify:(NSArray *)features {
    int length = (int)features.count;
    float *dataArray = new float[length];
    for (int i = 0; i < length; i++) dataArray[i] = [features[i] floatValue];
    Mat dataMat = Mat(1, length, CV_32F, dataArray);
    float result = svm->predict(dataMat);
    delete[] dataArray;
    return result;
}

@end
