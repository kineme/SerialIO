#import "QCProtocols.h"
#import "GFNodeManager.h"

int openDevice(NSString *dev, int baudRate, int parity, int dataBits, int stopBits);
int configDevice(int dev, int baudRate, int parity, int dataBits, int stopBits);
void closeDevice(int dev);

@interface KinemeSerialIOPatchPlugin : NSObject <GFPlugInRegistration>
+ (void)registerNodesWithManager:(GFNodeManager*)manager;
@end
