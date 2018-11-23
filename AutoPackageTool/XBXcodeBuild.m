//
//  XBXcodeBuild.m
//  XBPackTool
//
//  Created by 董玉毛 on 16/9/20.
//  Copyright © 2016年 dym. All rights reserved.
//

#import "XBXcodeBuild.h"
#import "ProjectConfig.h"
#import "XBProjectPath.h"

@implementation XBXcodeBuild

+ (NSString *)xcodeBuildType:(XcodeBuildType)type{
    if (type == XcodeBuildType_Debug) {
        return  @"Debug";
    }else{
        return @"Release";
    }
}

+ (void)xcodeBuildProjectSetBuildType:(NSString*)buildType{
    
    // 删除项目之前build的文件夹
//    [XBProjectPath deleteDerivedDataSubFolder];
    
    //切到项目目录
        NSString *cd = [NSString stringWithFormat:@"cd %@",XB_ProjectPath];
    
    // 1.清理工程
        NSString *clean = [NSString stringWithFormat:@"/usr/bin/xcodebuild -project %@.xcodeproj -scheme %@ clean",XB_ProjectName,XB_ProjectName];
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString *archivePath = [NSString stringWithFormat:@"/Users/tangjie/Library/Developer/Xcode/Archives/%@",[dateFormatter stringFromDate:date]];
    
    // 2.编译项目
        NSString *build = [NSString stringWithFormat:@"/usr/bin/xcodebuild archive\
                           -project %@.xcodeproj\
                           -scheme %@ \
                           -configuration %@ \
                           -archivePath %@" ,XB_ProjectName,XB_ProjectName,buildType,archivePath];
    
        NSString *shell1 = [NSString stringWithFormat:@"%@\n %@\n %@\n",cd,clean,build];
//    NSLog(@"--------------",[self executeCommand:shell1]);
        system([shell1 cStringUsingEncoding:NSUTF8StringEncoding]);
    
    NSString *exportOptionsPath = @"/Users/tangjie/Downloads/test/ExportOptions.plist";
    // 3.输出包
        NSString *run = [NSString stringWithFormat:@"/usr/bin/xcodebuild \
                         -exportArchive \
                         -archivePath %@ \
                         -exportPath %@ \
                         -exportOptionsPlist %@ \
                         -allowProvisioningUpdates",@"/Users/tangjie/Downloads/blm_CRM_BATE.xcarchive", @"/Users/tangjie/Downloads/Ipa",@"/Users/tangjie/Downloads/blm_CRM_BATE/ExportOptions.plist"];
    
    // 4.上传到蒲公英
    NSString *uploadToPgyer = [NSString stringWithFormat:@"curl -F 'file=@%@'\
                        -F '_api_key=%@' https://www.pgyer.com/apiv2/app/upload",@"/Users/tangjie/Downloads/Ipa/blm_CRM_BATE.ipa",XB_PgyerAPIKey];
    NSString *uploadToFir = [NSString stringWithFormat:@"fir p %@ -T %@",@"User/test.ipa",@"api token"];
    // 5.运行
        NSString *shell = [NSString stringWithFormat:@" %@\n %@\n",run,uploadToPgyer];
//        system([shell cStringUsingEncoding:NSUTF8StringEncoding]);
//    [self executeCommand:shell];
//    NSLog(@"cmdResult:%@", [self executeCommand:   @"ping www.baidu.com"]);
}
+ (NSString *)executeCommand: (NSString *)cmd

{
    
    NSString *output = [NSString string];
    
    FILE *pipe = popen([cmd cStringUsingEncoding: NSASCIIStringEncoding], "r+");
    
    if (!pipe)
        return @"";
    char buf[1024];
    
    while(fgets(buf, 1024, pipe)) {
        output = [output stringByAppendingFormat: @"%s", buf];
    }
    pclose(pipe);
    
    return output;
    
    
    
}

@end
