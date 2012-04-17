#import "FirstSerialViewController.h"
#import <MessageUI/MessageUI.h>
#import "RscMgr+IO.h"

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
    int i, int1, int2;

    NSMutableString *outStr = [NSMutableString stringWithString: @""];

    [outStr appendFormat:@"%C",(unichar)(0xAA)];
    [outStr appendFormat:@"%C",(unichar)(0x55)];
    [outStr appendFormat:@"%C",(unichar)(0x05)];
    [outStr appendFormat:@"%C",(unichar)(0x00)];
    [outStr appendFormat:@"%C",(unichar)(0x00)];
    [outStr appendFormat:@"%C",(unichar)(0x90)];

    for (i = 1; i < [self.inputField.text length]; i = i+3) {
        int1 = (int)[self.inputField.text characterAtIndex:i-1];
        int2 = (int)[self.inputField.text characterAtIndex:i];
        int1 -= (int1 < 65) ? 48 : ((int1 > 96) ? 87 : 55);
        int2 -= (int2 < 65) ? 48 : ((int2 > 96) ? 87 : 55);
        [outStr appendFormat:@"%C",(unichar)(int1*16+int2)];
    }
    [self.rscMgr writeString:outStr];
//    self.inputField.text = @"";

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

    NSMutableString *outStr = [NSMutableString stringWithString: @""];
    NSString *dataStr = [self.rscMgr readString:length];

    for (int i = 0; i < [dataStr length]; i++) {
        int int1 = (int)[dataStr characterAtIndex:i];
        [outStr appendFormat:@" %02X",int1];
    }
    self.outputLabel.text = outStr;
}

- (IBAction)eraseButton:(id)sender {
    int i, int1, int2;

    NSMutableString *outStr = [NSMutableString stringWithString: @""];
    // erase command = AA 55 02 05 02
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
}

- (IBAction)emailButton:(id)sender {

    if (![MFMailComposeViewController canSendMail]) return;

    MFMailComposeViewController *dispatch = [[MFMailComposeViewController alloc] init];
    dispatch.mailComposeDelegate = self;

	[dispatch setToRecipients:[NSArray arrayWithObject:@"genepope@comcast.net"]];
	[dispatch setCcRecipients:[NSArray arrayWithObject:@"genepope@comcast.net"]];
    [dispatch setSubject:@"data for meggitt"];

     NSString *emailBody = @"stuff for body";

     [dispatch setMessageBody:emailBody isHTML:NO];
     dispatch.navigationBar.barStyle = UIBarStyleBlack;
     [self presentModalViewController:dispatch animated:YES];
}

// Dismisses the email composition interface when users tap Cancel or Send. Proceeds to update the message field with the result of the operation.
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	// Notifies users about errors associated with the interface
	switch (result)
	{
		case MFMailComposeResultCancelled:
//			message.text = @"Result: canceled";
			break;
		case MFMailComposeResultSaved:
//			message.text = @"Result: saved";
			break;
		case MFMailComposeResultSent:
//			message.text = @"Result: sent";
			break;
		case MFMailComposeResultFailed:
//			message.text = @"Result: failed";
			break;
		default:
//			message.text = @"Result: not sent";
			break;
	}
	[self dismissModalViewControllerAnimated:YES];
}

@end
