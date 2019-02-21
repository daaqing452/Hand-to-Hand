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

- (id)initWithSVM:(NSString *)filePath {
    self = [super init];
    
    float trainDataC[][2] = {{0,0},{0,1},{1,0},{1,1}};
    Mat trainData(9, 2, CV_32F, trainDataC);
    Ptr<SVM> svm = SVM::load([filePath UTF8String]);
    
    for (int i = 0; i < 9; i++) {
        Mat nowData = trainData(Range(i,i+1), Range().all());
        /*float result = svm->predict(nowData);
        NSLog(@"%d: %f", i, result);*/
    }
    
    /*Ptr<SVM> svm = SVM::create();
    svm->setKernel(SVM::RBF);
    svm->setType(SVM::NU_SVC);*/
    
    NSLog(@"create classifier");
    return self;
}

- (void)classify:(NSArray *)features {
    unsigned long length = features.count;
    double *data = new double[length];
    for (int i = 0; i < length; i++) data[i] = [features[i] doubleValue];
    delete[] data;
}

@end
