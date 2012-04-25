#import "FirstSerialViewController.h"
#import <MessageUI/MessageUI.h>
#import "RscMgr+IO.h"

#define DEBUG_MODE

#ifdef DEBUG_MODE
#define DebugLog( s, ... ) NSLog( @"<%@:(%d)> %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define DebugLog( s, ... )
#endif

#define CMD 0
#define VAL 1
#define SUCCESSFULERASERESULT @"00 00 00 41"
#define AUTOLOADCHAR 0x2A   
#define MARRAYSIZE 50

#define NONEFLAG  0
#define ERASEFLAG  1
#define AUTOLOADFLAG 2

int stateFlag = NONEFLAG;
int autoDownLoadStatus;
int merrittData[MARRAYSIZE][2];   // [,0] = cmd val, [,1] = result val
int mDataSize = 0;

@implementation FirstSerialViewController

@synthesize connectionLabel, inputField, outputLabel, sendButton, eraseButton, emailButton;

@synthesize rscMgr;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.rscMgr = [[RscMgr alloc] init];
    
    // interestingly, setDelegate is a method and not property
    // contrary to Cocoa conventions.
    [self.rscMgr setDelegate:self];
    
    // simple serial port config interface
    // can be called anytime (even after open: call)
    // probably redundant since same code is in cableConnected()
    [self.rscMgr setBaud:2400];
    [self.rscMgr setDataSize:kDataSize8];
    [self.rscMgr setParity:kParityOdd];
    [self.rscMgr setStopBits:kStopBits1];
    [self.rscMgr setDtr: TRUE];
    [self.rscMgr setRts: FALSE];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.inputField becomeFirstResponder];
}

#pragma mark - methods

- (IBAction)send {
    int i, int1, int2, int3, ival;
    
    if ([self.inputField.text characterAtIndex:0] == AUTOLOADCHAR) {
        /* =============================
         ------ recursive calls to automate a download -------
         also, poorman's handshaking.  when readBytesAvailable receives data
         it will increment mDataSize.  so we'll just hang out after each
         send til that happens.  probably oughta put in some kind of loop 
         count to avoid hanging on an error...
         ================================*/
        autoDownLoadStatus = 1;
        mDataSize = 0;
    }
    if (!autoDownLoadStatus) {
        switch (autoDownLoadStatus) {
            case 1:
                self.inputField.text = @"00 00";    // expected return in no data case:15 40 00 10
                break;
            case 2:
                self.inputField.text = @"00 01";    // expected:15 40 00 00
                break;
            case 3:
                self.inputField.text = @"00 02";    // expected:15 40 00 F8
                break;
            case 4:
                self.inputField.text = @"00 03";    // expected:15 40 00 00
                break;
            case 5:
                self.inputField.text = @"00 04";    // expected:15 40 10 18
                break;

            case 6:
                self.inputField.text = @"00 05";    // expected:15 40 00 0F
                break;
            case 7:
                self.inputField.text = @"00 06";    // expected:15 40 10 78
              break;
            case 8:
                self.inputField.text = @"00 07";    // expected:15 40 00 0F
              break;
            case 9:
                self.inputField.text = @"00 08";    // expected:15 40 2F F9
               break;
            case 10:
                self.inputField.text = @"00 09";    // expected:15 40 00 00
                break;
 
            case 11:
                self.inputField.text = @"00 0A";    // expected:15 40 00 00
                break;
            case 12:
                self.inputField.text = @"00 0B";    // expected:15 40 00 01
                break;
            case 13:
                self.inputField.text = @"00 0C";    // expected:15 40 78 68
               break;
            case 14:
                self.inputField.text = @"00 0D";    // expected:15 40 0F 10
               break;
            case 15:
                self.inputField.text = @"00 30";    // expected:15 40 0F 0F
                break;
 
            case 16:
                self.inputField.text = @"00 31";    // expected:15 40 0F 0F
               break;
            case 17:
                self.inputField.text = @"00 30";    // expected:15 40 3F 3F
               break;
            case 18:
                self.inputField.text = @"00 80";    // expected:15 40 FF FF
                break;
            case 29:
                self.inputField.text = @"00 81";    // expected:15 40 FF FF
                break;

            default:
                autoDownLoadStatus = 0;
                return;
                break;
        }        
    }

    NSMutableString *outStr = [NSMutableString stringWithString: @""];
    
    [outStr appendFormat:@"%C",(unichar)(0xAA)];
    [outStr appendFormat:@"%C",(unichar)(0x55)];
    [outStr appendFormat:@"%C",(unichar)(0x05)];
    [outStr appendFormat:@"%C",(unichar)(0x00)];
    [outStr appendFormat:@"%C",(unichar)(0x00)];
    [outStr appendFormat:@"%C",(unichar)(0x90)];
    
    for (ival = 0, i = 1; i < [self.inputField.text length]; i = i+3) {
        int1 = (int)[self.inputField.text characterAtIndex:i-1];
        int2 = (int)[self.inputField.text characterAtIndex:i];
        int1 -= (int1 < 65) ? 48 : ((int1 > 96) ? 87 : 55);
        int2 -= (int2 < 65) ? 48 : ((int2 > 96) ? 87 : 55);
        
        int3 = int1*16+int2;
        ival  = (ival << 8)+ int3;
        [outStr appendFormat:@"%C",(unichar)int3];
    }
    [self.rscMgr writeString:outStr];
    //    self.inputField.text = @"";
    
    merrittData[mDataSize][CMD] = ival;   // store cmd value in array
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.rscMgr writeString:self.inputField.text];
    self.inputField.text = @"";
    self.outputLabel.text = @"";
    
    return YES;
}

#pragma mark - RscMgrDelegate

- (void)cableConnected:(NSString *)protocol {
    
    self.connectionLabel.text = @"Connected";
    self.connectionLabel.textColor = [UIColor greenColor];
    
    self.inputField.enabled = YES;
    self.sendButton.enabled = YES;
    self.eraseButton.enabled = YES;
    self.emailButton.enabled = [MFMailComposeViewController canSendMail];
    
    [self.rscMgr setBaud:2400];
    [self.rscMgr setDataSize:kDataSize8];
    [self.rscMgr setParity:kParityOdd];
    [self.rscMgr setStopBits:kStopBits1];
    [self.rscMgr setDtr: TRUE];
    [self.rscMgr setRts: FALSE];
}

- (void)cableDisconnected {
    self.connectionLabel.text = @"Disconnected";
    self.connectionLabel.textColor = [UIColor redColor];
    
    self.inputField.enabled = NO;
    self.sendButton.enabled = NO;
    self.eraseButton.enabled = NO;
    self.emailButton.enabled = NO;
}

- (void)portStatusChanged {
    // do nothing
    /*
     txDiscard,          // non-zero if tx data msg from App discarded
     rxOverrun,	        // non-zero if overrun error occurred
     rxParity,			// non-zero if parity error occurred
     rxFrame,			// non-zero if frame error occurred
     txAck,				// ack when tx buffer becomes empty (sent only if txAxkSetting non-zero in config)
     msr,				// 0-3 current modem status bits for CTS, DSR, DCD & RI, 4-7 previous modem status bits, MODEM_STAT_
     rtsDtrState,        // 0-3 current modem status bits for RTS & DTR, 4-7 previous modem status bits, MODEM_STAT_
     rxFlowStat,			// rx flow control off= 0 on = RXFLOW_RTS/DTR/XOFF
     txFlowStat,			// rx flow control off= 0 on = TXFLOW_DCD/CTS/DSR/XOFF
     returnResponse;		// Non-zero if returned in response to config or control
     // message with returnStatus requested (non-zero). If non-zero the
     // value will equal the returnStatus byte.
     */
    self.outputLabel.text = @"";
}

- (void)readBytesAvailable:(UInt32)length {
    int dataInt;
    
    NSMutableString *outStr = [NSMutableString stringWithString: @""];
    NSString *dataStr = [self.rscMgr readString:length];
    
    for (int i = dataInt = 0; i < [dataStr length]; i++) {
        int int1 = (int)[dataStr characterAtIndex:i];
        [outStr appendFormat:@" %02X",int1];
        dataInt = (dataInt << 8) + int1;
    }
    self.outputLabel.text = outStr;
    
    if (stateFlag == ERASEFLAG) {
        NSMutableString *alertStr = [NSMutableString stringWithString: ([outStr isEqualToString: SUCCESSFULERASERESULT]) ? @"Successful " : @"Failed"];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Erase Command:" message:alertStr delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        //      [alert release];           
        
        if ([outStr isEqualToString: SUCCESSFULERASERESULT]) mDataSize = 0;
        stateFlag = NONEFLAG;
    }
    else if (autoDownLoadStatus) {
        merrittData[autoDownLoadStatus++][VAL] = dataInt;
        [self send];
    }
    else {
        //oops. ERROR!
    }
}

- (IBAction)eraseButton:(id)sender {
    int i, int1, int2;
    
    // erase command = AA 55 02 05 02
    NSMutableString *outStr = [NSMutableString stringWithString: @""];
    [outStr appendFormat:@"%C",(unichar)(0xAA)];
    [outStr appendFormat:@"%C",(unichar)(0x55)];
    [outStr appendFormat:@"%C",(unichar)(0x02)];
    [outStr appendFormat:@"%C",(unichar)(0x05)];
    [outStr appendFormat:@"%C",(unichar)(0x02)];
    for (i = 1; i < [self.inputField.text length]; i = i+3) {
        int1 = (int)[self.inputField.text characterAtIndex:i-1];
        int2 = (int)[self.inputField.text characterAtIndex:i];
        int1 -= (int1 < 65) ? 48 : ((int1 > 96) ? 87 : 55);
        int2 -= (int2 < 65) ? 48 : ((int2 > 96) ? 87 : 55);
        [outStr appendFormat:@"%C",(unichar)(int1*16+int2)];
    }
    [self.rscMgr writeString:outStr];
    // check return value. should be 0x41. Alert for other values.
    stateFlag = ERASEFLAG;
}

- (IBAction)emailButton:(id)sender {
    
    if (![MFMailComposeViewController canSendMail]) return;
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    
    [picker setToRecipients:[NSArray arrayWithObject:[[NSUserDefaults standardUserDefaults] stringForKey:@"to"]]];
    [picker setCcRecipients:[NSArray arrayWithObject:[[NSUserDefaults standardUserDefaults] stringForKey:@"cc"]]];
  
    [picker setSubject:[[NSUserDefaults standardUserDefaults] stringForKey:@"tail"]];
    
    NSMutableString *emailBody = [NSMutableString stringWithString: @""];
    for (int i = 0; i < mDataSize; i++) {
        [emailBody appendFormat:@"%04X %04X \r\n",merrittData[i][CMD],merrittData[i][VAL]];
        
    }
    [picker setMessageBody:emailBody isHTML:NO];
    picker.navigationBar.barStyle = UIBarStyleBlack;
    [self presentModalViewController:picker animated:YES];
}

// Dismisses the email composition interface when users tap Cancel or Send. Proceeds to update the message field with the result of the operation.
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	// Notifies users about errors associated with the interface
    NSMutableString *alertStr = [NSMutableString stringWithString:@""];
	switch (result)
	{
		case MFMailComposeResultCancelled:
        [alertStr appendString: @"Result: Cancelled"];
        break;
		case MFMailComposeResultSaved:
        [alertStr appendString: @"Result: Saved"];
        break;
		case MFMailComposeResultSent:
        [alertStr appendString: @"Result: Sent"];
        break;
		case MFMailComposeResultFailed:
        [alertStr appendString: @"Result: Failed"];
        break;
		default:
        [alertStr appendString: @"Result: Not Sent"];
        break;
	}        
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Email Message:" message:alertStr delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    
    [alert show];
    //      [alert release];           
	[self dismissModalViewControllerAnimated:YES];
}

/*
 DebugLog(@"process Name: %@ Process ID: %d",@"yes!!",12);
 
 NSLog(@"process Name: %@ Process ID: %d",string);
 
 MFMailComposeViewController NSString* myNewString = [NSString stringWithFormat:@"%i", stateFlag];
 UIAlertView *xalert = [[UIAlertView alloc] initWithTitle:@"000 Command:" message:myNewString delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
 [xalert show];
 
 [NSString stringWithFormat:@"%@/%@/%@", three, two, one];
 
 UIAlertView *yalert = [[UIAlertView alloc] initWithTitle:@"111 Command:" message:outStr delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
 [yalert show];
 NSString *out2Str;
 out2Str = [outStr stringByReplacingOccurrencesOfString:@" "                                                     withString: @""];
 
 UIAlertView *zalert = [[UIAlertView alloc] initWithTitle:@"333 Command:" message:out2Str delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
 [zalert show];
 
 */

@end
