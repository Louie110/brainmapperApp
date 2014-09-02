//
//  BRM_AppController.h
//  brainmapper
//
//  Created by Joost Wagenaar on 11/6/12.
//  Copyright (c) 2012 University of Pennsylvania. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRM_AppController : NSObject
{
    IBOutlet NSTextField *textField;
    IBOutlet NSButton *startButton;

    IBOutlet NSPathControl *targetPathCtl;
    IBOutlet NSPathControl *ctPathCtl;
    IBOutlet NSPathControl *mriPathCtl;
    IBOutlet NSProgressIndicator *processInd;

    IBOutlet NSButton *destPathHelpButton;
    IBOutlet NSButton *checkBoxesHelpButton;
    IBOutlet NSButton *tableViewHelpButton;
    IBOutlet NSButton *progressHelpButton;
 
    NSString *destPath;
    Boolean inclSegm;
    dispatch_queue_t bgqueue, main;
   
    
}

//properties related to view
@property (assign) IBOutlet NSWindow *window;
@property (readonly) Boolean inclSegm;
@property (nonatomic) NSView *corner;

//properties related to coregistration process
@property (copy) NSString *destPath, *resPath, *ctPath, *mriPath;
@property (nonatomic) IBOutlet NSPathControl *targetPathCtl;
@property (nonatomic) IBOutlet NSPathControl *mriPathCtl, *ctPathCtl;
@property (strong, nonatomic) IBOutlet NSTextField *threshold;
@property (strong, nonatomic) IBOutlet NSButtonCell *startButtonText;

//properties related to providing feedback
@property (strong, nonatomic) IBOutlet NSTextField *textField;
@property (nonatomic) IBOutlet NSPopover *destPathPopover;
@property (nonatomic) IBOutlet NSPopover *checkBoxesPopover;
@property (nonatomic) IBOutlet NSPopover *tableViewPopover;
@property (nonatomic) IBOutlet NSPopover *progressPopover;


//Methods & Actions Involved in Coregistration Process
- (IBAction)start:(id)sender;
- (void)stackDicoms:(NSString*)inDcm forFile:(NSString*)inFile;
- (void)coregScript;
- (void)pathControlDoubleClick:(id)sender;

//Methods & Actions Involved in providing feedback
- (void)monitorUpdateFile;
- (void)generateUpdate:(NSString *)words;
- (void)incrementProgress:(NSNumber*)target;
- (IBAction)destPathHelpButtonPushed:(id)sender;
- (IBAction)checkBoxesHelpButtonPushed:(id)sender;
- (IBAction)tableViewHelpButtonPushed:(id)sender;
- (IBAction)progressHelpButtonPushed:(id)sender;


@end
