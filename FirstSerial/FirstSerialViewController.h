#import <UIKit/UIKit.h>

#import "RscMgr.h"
#import <MessageUI/MFMailComposeViewController.h>

@interface FirstSerialViewController : UIViewController <UITextFieldDelegate, RscMgrDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, retain) IBOutlet UILabel *connectionLabel;
@property (nonatomic, retain) IBOutlet UITextField *inputField;
@property (nonatomic, retain) IBOutlet UILabel *outputLabel;
@property (nonatomic, retain) IBOutlet UIButton *sendButton;
@property (nonatomic, retain) IBOutlet UIButton *eraseButton;
@property (nonatomic, retain) IBOutlet UIButton *emailButton;
@property (nonatomic, retain) RscMgr *rscMgr;

- (IBAction)send;
- (IBAction)eraseButton:(id)sender;
- (IBAction)emailButton:(id)sender;

@end
