@interface KinemeSerialOutput : QCPatch
{
	QCStringPort	*inputDevice;
	QCIndexPort		*inputBaudRate;
	QCIndexPort		*inputParity;
	QCIndexPort		*inputDataBits;
	QCIndexPort		*inputStopBits;

	QCStringPort	*inputData;
	QCBooleanPort	*inputTrigger;
	
	QCStringPort	*inputBinaryData;
	QCBooleanPort	*inputBinaryTrigger;
	
	NSString		*deviceName;
	int				serialDevice;
	int				baudRate;
	int				parity;
	int				dataBits;
	int				stopBits;
	BOOL			oldTrigger;
	BOOL			oldBinaryTrigger;
}

- (id)initWithIdentifier:(id)fp8;

//- (id)setup:(QCOpenGLContext *)context;
//- (void)cleanup:(QCOpenGLContext *)context;

//- (void)enable:(QCOpenGLContext *)context;
//- (void)disable:(QCOpenGLContext *)context;

- (BOOL)execute:(QCOpenGLContext *)context time:(double)time arguments:(NSDictionary *)arguments;
@end
