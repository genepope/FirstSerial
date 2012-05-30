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
#define SUCCESSFULERASERESULT @"41"
#define AUTOLOADCHAR 0x2A
#define MARRAYSIZE 50

#define NONEFLAG 0
#define ERASEFLAG 1
#define AUTOLOADFLAG 2

int stateFlag = NONEFLAG;
int autoDownLoadStatus;
int merrittData[MARRAYSIZE][2]; // [,0] = cmd val, [,1] = result val
int mDataSize = 0;
int recordNum;

NSMutableString *formattedStr, *blockStr, *excelStr, *merrittStr;

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
    
    formattedStr = [NSMutableString stringWithString: @""];
    blockStr = [NSMutableString stringWithString: @""];
    excelStr = [NSMutableString stringWithString: @""];
    merrittStr = [NSMutableString stringWithString: @""];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.inputField becomeFirstResponder];
}

#pragma mark - methods

- (IBAction)send {
    int i, int1, int2, int3, ival;
    
    DebugLog(@"enter send. Point 1");
    
    if ([self.inputField.text length] != 0) { //Only do something if we have string input (for now)
        
    if ([self.inputField.text characterAtIndex:0] == AUTOLOADCHAR) {
        /*  BASIC DESCRIPTION OF HOW TO DOWNLOAD DATA FROM THE MERRIDIAN'S SERIAL PORT:   
         first, 18 locs are read in, the "header" locs.  starting at 00 00 thru 00 0D, then 2030/31 and 2080/81.  always the same result, except for 2030/31 and 2080/81.  the 1st result (from 00 00) has to be 0x10 or it forces an error.  all the other results of the first 14 commands don't matter - they're ignored, unless there's no return at all, which causes an err.  each ectm record is 20 locs.  it can either come from block 1 or block 2.  if 2030/31 returns 3F3F3F3F then block 1 is used starting at 0x2000/0x2400.  otherwise block 2 is used starting at 0x4000/0x4400. 
         
         20 locs are requested for each ectm record.
         
         the meaning of each of the 20 results:
         
         day = (value(1,2)>>14)&0x1F      
         month = (value(1,2)>>8)&0x3F 
         year = (value(1,2)>>2)&0x3F 
         hour = (value(1,2)>>26)&0x0F 
         minute = (value(3,4))&0x1F 
         second = (value(1,2)>>19)&0x7F 
         mode = value(3,4)&0x3;
         altitude = value(5,6) *1.0            
         airspeed = value(7,8) *.0625   
         SAT = value(9,10) *.25
         torque = value(11,12) * .0625 * 13.13
         Np = value(13,14) * .015625
         Ng = value(15,16) * .015625
         ITT = value(17,18) * .5
         fuel flow = value(19,20) * 1.0
         
         the number of ectm records for each report is a function of 2080/2081 (or 4080/4081).  it's calc'd with bit shifts.  basically it's the number of 0's on the right side of the result:
         
         2080/2081:  FF FF FF FF = 1111 1111 1111 1111 1111 1111 1111 1111 = 0
         2080/2081:  FF FF FF FE = 1111 1111 1111 1111 1111 1111 1111 1110 = 1
         2080/2081:  FF FF FF FC = 1111 1111 1111 1111 1111 1111 1111 1100 = 2
         2080/2081:  FF FF FF F8 = 1111 1111 1111 1111 1111 1111 1111 1000 = 3
         2080/2081:  FF FF FF F0 = 1111 1111 1111 1111 1111 1111 1111 0000 = 4
         etc…
         */
        autoDownLoadStatus = 1;
        [blockStr setString: @"00 "];
        [formattedStr setString: @""];
        [excelStr setString: @""];
        [merrittStr setString: @""];
        mDataSize = 0;
    }
 
    DebugLog(@"send. Point 2");

    if (autoDownLoadStatus) {
        //first, do the 14 loc header
        [formattedStr setString: blockStr];
        if (autoDownLoadStatus <= 14) {
            [formattedStr appendFormat: @"%02X",autoDownLoadStatus-1];
        }
        //then try either 2030/2031 or 4030/3031 for return value of 0x3F3F, to indicate which block to use
        else if (autoDownLoadStatus >= 15 || autoDownLoadStatus <= 18) {
            [formattedStr appendFormat: @"%02X",(autoDownLoadStatus^1)+30];
        }
        //now check 2080/2081 or 4080/4081, to see how many records there are
        else if (autoDownLoadStatus == 19 || autoDownLoadStatus == 20) {
            [formattedStr appendFormat: @"%02X",(autoDownLoadStatus^1)+80];
        }
        // and finally, read in each record in chunks of 20 locs for each
        else {
            [formattedStr appendFormat: @"%02X",((recordNum-1) * 20)+autoDownLoadStatus%20];
        }
        self.inputField.text = formattedStr;
    }
    
    DebugLog(@"send. Point 3");

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
        ival = (ival << 8)+ int3;
        [outStr appendFormat:@"%C",(unichar)int3];
    }

    DebugLog(@"send. Point 4");

    [self.rscMgr writeString:outStr];
    // self.inputField.text = @"";
    
    merrittData[mDataSize][CMD] = ival; // store cmd value in array
    }
    else 
    {        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Enter something like * or commands" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
        [alert show];
        // [alert release];
        //        [alertStr appendString: @"Enter something like * or commands"];
    }
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
     txDiscard, // non-zero if tx data msg from App discarded
     rxOverrun, // non-zero if overrun error occurred
     rxParity, // non-zero if parity error occurred
     rxFrame, // non-zero if frame error occurred
     txAck, // ack when tx buffer becomes empty (sent only if txAxkSetting non-zero in config)
     msr, // 0-3 current modem status bits for CTS, DSR, DCD & RI, 4-7 previous modem status bits, MODEM_STAT_
     rtsDtrState, // 0-3 current modem status bits for RTS & DTR, 4-7 previous modem status bits, MODEM_STAT_
     rxFlowStat, // rx flow control off= 0 on = RXFLOW_RTS/DTR/XOFF
     txFlowStat, // rx flow control off= 0 on = TXFLOW_DCD/CTS/DSR/XOFF
     returnResponse; // Non-zero if returned in response to config or control
     // message with returnStatus requested (non-zero). If non-zero the
     // value will equal the returnStatus byte.
     */
    self.outputLabel.text = @"";
}

- (void)readBytesAvailable:(UInt32)length {
    int dataInt;
    
    NSMutableString *outStr = [NSMutableString stringWithString: @""];
    NSString *dataStr = [self.rscMgr readString:length];
         
    DebugLog(@"enter readBytesAvailable. Point 1");
    
   for (int i = dataInt = 0; i < [dataStr length]; i++) {
        int int1 = (int)[dataStr characterAtIndex:i];
        [outStr appendFormat:@" %02X",int1];
        dataInt = (dataInt << 8) + int1;
    }

    DebugLog(@"readBytesAvailable. Point 2");

    self.outputLabel.text = outStr;
    
    if (stateFlag == ERASEFLAG) {
        
        DebugLog(@"readBytesAvailable ERASEFLAG. Point 3a");
        
       NSMutableString *alertStr = [NSMutableString stringWithString: ([outStr isEqualToString: SUCCESSFULERASERESULT]) ? @"Successful " : [NSString stringWithFormat:@"%@/%@",@"Failed ",outStr]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Erase Command:" message:alertStr delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        // [alert release];
        
        if ([outStr isEqualToString: SUCCESSFULERASERESULT]) mDataSize = 0;
        stateFlag = NONEFLAG;
 
        DebugLog(@"readBytesAvailable ERASEFLAG. Point 3b");
        
}
    else if (autoDownLoadStatus) {
                
        DebugLog(@"readBytesAvailable. Point 4");
        
      [excelStr appendFormat:@"%3d, 0x%4X, 0x%4X, %6d, %6d\r\n",autoDownLoadStatus, merrittData[mDataSize][CMD], dataInt, merrittData[mDataSize][CMD], dataInt];
                
        if (autoDownLoadStatus == 1) {
            if (dataInt != 0x10) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Comm Failed:" message:[NSString stringWithFormat:@"%@ %3d 0x%4X",@"Error 1:",autoDownLoadStatus,dataInt] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                autoDownLoadStatus = 0;
                mDataSize = 0;
                return;
            }
        }
 
        if (autoDownLoadStatus == 14) {
            [blockStr setString: @"20 "];
        } else if (autoDownLoadStatus == 16) {
            if (dataInt == 0x3F3F) {
                autoDownLoadStatus = 18;
            } else [blockStr setString: @"40 "];
        } else if (autoDownLoadStatus == 18) {
            if (dataInt != 0x3F3F) {} // error!
        } else if (autoDownLoadStatus == 20) {
            // the number of ECTM records is the number of binary 0's on the right side of dataInt
            recordNum = 0;
            while (dataInt^1) {
                dataInt >>= 1;
                recordNum++;
            }
            if (!recordNum) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"THERE IS NO DATA" message:[NSString stringWithFormat:@""] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                autoDownLoadStatus = 0;
                mDataSize = 0;
                return;
            }
            if ([blockStr isEqualToString: @"20 "]) {
                [blockStr setString: @"24 "];
            } else [blockStr setString: @"44 "];
            /*
             3 ECTM events on aircraft N46ME  Monday, October 17, 2011 19:34:39
             Date       Time       Mode  Altitude  Airspeed  SAT  Torque  Np     Ng    ITT   Fuel Flow 
             10/18/11   01:21:18    2     15572      179     -1   1146    100   90.5   629     289
             10/17/11   21:22:36    2     17972      179     -8   1169    100   91.0   630     281
             06/10/11   15:10:36    2     15224      146     -4   1218    100   91.3   628     301
             */
            NSDate *date = [NSDate date];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
            [dateFormatter setDateFormat:@"EEEE MMMM dd, yyyy HH:mm:ss"];
            [merrittStr appendFormat:@"%3d	ECTM	events	on	aircraft	?????  %@",recordNum,[dateFormatter stringFromDate:date]];
            [merrittStr appendString:@"\r\nDate       Time       Mode  Altitude  Airspeed  SAT  Torque  Np     Ng    ITT   Fuel Flow\r\n"];
        } else if (autoDownLoadStatus%20 == 0) {
            int day = (((merrittData[0][VAL]<<16)+merrittData[1][VAL])>>14)&0x1F;      
            int month = (((merrittData[0][VAL]<<16)+merrittData[1][VAL])>>8)&0x3F; 
            int year = (((merrittData[0][VAL]<<16)+merrittData[1][VAL])>>2)&0x3F; 
            int hour = (((merrittData[0][VAL]<<16)+merrittData[1][VAL])>>26)&0x0F;
            int minute = (((merrittData[2][VAL]<<16)+merrittData[3][VAL]))&0x1F; 
            int second = (((merrittData[0][VAL]<<16)+merrittData[1][VAL])>>19)&0x7F; 
            int mode = (((merrittData[2][VAL]<<16)+merrittData[3][VAL]))&0x3;
            float altitude = ((merrittData[4][VAL]<<16)+merrittData[5][VAL]) *1.0;
            float airspeed = ((merrittData[6][VAL]<<16)+merrittData[7][VAL]) *.0625;
            float sat = ((merrittData[8][VAL]<<16)+merrittData[9][VAL]) *.25;
            float torque = ((merrittData[10][VAL]<<16)+merrittData[11][VAL]) * .0625 * 13.13;
            float np = ((merrittData[12][VAL]<<16)+merrittData[13][VAL]) * .015625;
            float ng = ((merrittData[14][VAL]<<16)+merrittData[15][VAL]) * .015625;
            float itt = ((merrittData[16][VAL]<<16)+merrittData[17][VAL]) * .5;
            float fuelflow = ((merrittData[18][VAL]<<16)+merrittData[19][VAL]) * 1.0;
            [merrittStr appendFormat:@"%2d/%2d/%2d   %2d:%2d:%2d    %1d    %5f      %3f    %3f   %4f    %3f   %4f.1   %3f    %4f\r\n",month,day,year,hour,minute,second,mode,altitude,airspeed,sat,torque,np,ng,itt,fuelflow];
            mDataSize = 0;
            recordNum--;
        }
 
        DebugLog(@"readBytesAvailable. Point 5");
        
       merrittData[mDataSize++][VAL] = dataInt;//store return result into array
        if (recordNum) {
            autoDownLoadStatus++;
            [self send];
        } else autoDownLoadStatus = 0;
    }
}

- (IBAction)eraseButton:(id)sender {
    int i, int1, int2;
    
    // erase command = AA 55 02 05 02

    DebugLog(@"enter eraseButton. Point 1");

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

    DebugLog(@"exit eraseButton. Point 2");
    
}

- (IBAction)emailButton:(id)sender {
    
    NSUserDefaults *user = [NSUserDefaults standardUserDefaults];
    if (![user stringForKey:@"to"] || ![user stringForKey:@"cc"] || ![user stringForKey:@"tail"]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Email Command:" message:@"App Preferences must first be set up in iPhone Settings!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    if (![MFMailComposeViewController canSendMail]) return;
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    
    // these picker calls will crash if the values looked up are NIL.
    [picker setToRecipients:[NSArray arrayWithObject:[[NSUserDefaults standardUserDefaults] stringForKey:@"to"]]];
    [picker setCcRecipients:[NSArray arrayWithObject:[[NSUserDefaults standardUserDefaults] stringForKey:@"cc"]]];
    NSString *tail = [[NSUserDefaults standardUserDefaults] stringForKey:@"tail"];
    [picker setSubject:tail];
    [merrittStr stringByReplacingOccurrencesOfString:@"?????" withString:tail];
    NSMutableString *emailBody = [NSMutableString stringWithString: merrittStr];
    [emailBody appendString:@"\r\n\r\n"];
    [emailBody appendString:excelStr];
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
    // [alert release];
    [self dismissModalViewControllerAnimated:YES];
}
@end