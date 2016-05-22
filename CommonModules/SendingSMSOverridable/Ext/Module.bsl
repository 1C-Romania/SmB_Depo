////////////////////////////////////////////////////////////////////////////////
// Subsystem "Sending SMS"
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Sends SMS via configured service provider, returns message identifier.
//
// Parameters:
//  SendingParameters - Structure -
//    Provider - EnumRef.SMSProviders - the service provider for sending SMS.
//    RecipientNumbers  - Array - an array of number strings of the recipients in the format +7XXXXXXXXXX;
//    Text             - String - message text, the maximum length can be different depending on the operator;
//    SenderName       - String - the sender name that will be shown instead of numbers for recipients.
//    Login            - String - login to access the service of sending SMS.
//    Password         - String - password to access the service of sending SMS.
//  Result - Structure - (return value):
//    SentMessages - Array of structures:
//      RecipientNumber - String - the recipient's number from the array RecipientNumbers;
//      MessageID - String - SMS ID by which you can request the sending status.
//    ErrorDescription - String - user presentation of an error if the string is empty, then there is no error.
//
Procedure SendSMS(SendingParameters, Result) Export
	
	
	
EndProcedure

// Requests a delivery status of the SMS from the service provider.
//
// Parameters:
//  MessageID - String - the ID assigned when sending SMS;
//  Login              - String - login to access the service of sending SMS.
//  Password           - String - password to access the service of sending SMS.
//  Result             - String - (return value) delivery status, see the description of the SendingSMS function.DeliveryStatus.
Procedure DeliveryStatus(MessageID, Provider, Login, Password, Result) Export 
	
	
	
EndProcedure

// Checks the correctness of saved settings of SMS sending.
//
// Parameters:
//  SendingSMSSettings - Structure:
//   * Provider - EnumRef.SMSProviders;
//   * Login - String;
//   * Password - String.
//  Cancel - Boolean - set this parameter to True if the settings are not filled or filled incorrectly.
//
Procedure WhenTestingSendSMSSettings(SendingSMSSettings, Cancel) Export

EndProcedure

// Complement the list of permissions for sending the SMS.
//
// Parameters:
//  Permissions - Array - the array of objects returned by one of the WorkInSafeMode.Permission*() functions.
//
Procedure OnReceiptPermissions(permissions) Export
	
EndProcedure

#EndRegion
