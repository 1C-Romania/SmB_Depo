////////////////////////////////////////////////////////////////////////////////
// Subsystem "BaseFunctionality".
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Basic functionality

// See CommonUse.WSProxy()
//
Function WSProxy(
			Val WSDLAddress,
			Val NamespaceURI,
			Val ServiceName,
			Val EndpointName = "",
			Val UserName,
			Val Password,
			Val Timeout = 0,
			Val MakeTestCall = False) Export
	
	Return CommonUse.WSProxy(WSDLAddress,
			NamespaceURI,
			ServiceName,
			EndpointName,
			UserName,
			Password,
			Timeout,
			MakeTestCall);
	
EndFunction

// See CommonUse.ValueToXMLString()
//
Function ValueToXMLString(Val Value) Export
	
	Return CommonUse.ValueToXMLString(Value);
	
EndFunction

// See CommonUse.SetSessionSeparation()
//
Procedure SetSessionSeparation(Val Use, Val DataArea = Undefined) Export
	
	CommonUse.SetSessionSeparation(Use, DataArea);
	
EndProcedure

// See CommonUse.LockInfobase()
//
Procedure LockInfobase(Val CheckNoOtherSessions = True) Export
	
	CommonUse.LockInfobase(CheckNoOtherSessions);
	
EndProcedure

// See CommonUse.UnlockInfobase()
//
Procedure UnlockInfobase() Export
	
	CommonUse.UnlockInfobase();
	
EndProcedure

// See CommonUse.SubjectString()
//
Function SubjectString(Val SubjectRef) Export
	
	Return CommonUse.SubjectString(SubjectRef);
	
EndFunction

// See CommonUseReUse.DataSeparationEnabled()
//
Function DataSeparationEnabled() Export
	
	Return CommonUseReUse.DataSeparationEnabled();
	
EndFunction

// See CommonUseReUse.CanUseSeparatedData()
//
Function CanUseSeparatedData() Export
	
	Return CommonUseReUse.CanUseSeparatedData();
	
EndFunction

// See CommonUseReUse.SessionSeparatorValue()
//
Function SessionSeparatorValue() Export
	
	Return CommonUse.SessionSeparatorValue();
	
EndFunction

// See CommonUseReUse.SupportDataSplitter()
//
Function SupportDataSplitter() Export
	
	Return CommonUseReUse.SupportDataSplitter();
	
EndFunction

// See CommonUse.OnCreateAtServer()
//
Function OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	Return CommonUse.OnCreateAtServer(Form, Cancel, StandardProcessing);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// CommonUseClientServer

// See CommonUseClientServer.SubsystemExist()
//
Function SubsystemExists(SubsystemFullName) Export
	
	Return CommonUseClientServer.SubsystemExists(SubsystemFullName);
	
EndFunction

// See CommonUseClientServer.CommonModule()
//
Function CommonModule(Name) Export
	
	Return CommonUseClientServer.CommonModule(Name);
	
EndFunction

// See CommonUseClientServer.CommonGroupLineDisplaying()
//
Function CommonGroupLineDisplaying() Export
	
	Return CommonUseClientServer.CommonGroupLineDisplaying();
	
EndFunction

// See CommonUseClientServer.MainLanguageCode()
//
Function MainLanguageCode() Export
	
	Return CommonUseClientServer.MainLanguageCode();
	
EndFunction

// See CommonUseClientServer.CompareVersions()
//
Function CompareVersions(Val VersionString1, Val VersionString2) Export
	
	Return CommonUseClientServer.CompareVersions(VersionString1, VersionString2);
	
EndFunction

// See CommonUseClientServer.MessageToUser()
//
Procedure MessageToUser(
		Val MessageToUserText,
		Val DataKey = Undefined,
		Val Field = "",
		Val DataPath = "",
		Cancel = False) Export
	
	CommonUseClientServer.MessageToUser(MessageToUserText,
		DataKey,	Field, DataPath, Cancel);
	
EndProcedure

// See CommonUseClientServer.ObjectManagerByFullName()
//
Function ObjectManagerByFullName(FullMetadataObjectName) Export
	
	Return CommonUse.ObjectManagerByFullName(FullMetadataObjectName)
	
EndFunction

// See CommonUseClientServer.SupplementTable()
//
Procedure SupplementTable(SourceTable, TargetTable) Export
	
	CommonUseClientServer.SupplementTable(SourceTable, TargetTable);
	
EndProcedure

// See CommonUseClientServer.ParseStringWithPostalAddresses()
//
Function ParseStringWithPostalAddresses(Val EmailAddressString, CallingException = True) Export 
	
	Return CommonUseClientServer.ParseStringWithPostalAddresses(EmailAddressString, CallingException);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// StringFunctionsClientServer

// See StringFunctionsClientServer.SubstituteParametersInString()
//
Function PlaceParametersIntoString(Val LookupString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val Parameter6 = Undefined,
	Val Parameter7 = Undefined, Val Parameter8 = Undefined, Val Parameter9 = Undefined) Export
	
	Return StringFunctionsClientServer.SubstituteParametersInString(LookupString,
		Parameter1, Parameter2, Parameter3, Parameter4, Parameter5, Parameter6, Parameter7, Parameter8, Parameter9);
	
EndFunction

// See StringFunctionsClientServer.ThisIsUUID()
//
Function ThisIsUUID(Val String) Export
	
	Return StringFunctionsClientServer.ThisIsUUID(String);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Basic functionality in the service model

// See MessagesSaaSReUse.TypeBody()
//
Function TypeBody() Export 
	
	Return MessagesSaaSReUse.TypeBody();
	
EndFunction

// See SaaSReUse.ServiceManagerEndPoint()
//
Function ServiceManagerEndPoint() Export
	
	Return SaaSReUse.ServiceManagerEndPoint();
	
EndFunction

// See SaaSOperations.ParametersSelections()
//
Function ParametersSelections(FullMetadataObjectName) Export 
	
	Return SaaSOperations.ParametersSelections(FullMetadataObjectName);
	
EndFunction

// See SaaSOperations.LockCurrentDataArea()
//
Procedure LockCurrentDataArea(Val CheckNoOtherSessions = False, Val SeparatedLock = False) Export
	
	SaaSOperations.LockCurrentDataArea(CheckNoOtherSessions, SeparatedLock);
	
EndProcedure

// See SaaSOperations.UnlockCurrentDataArea()
//
Procedure UnlockCurrentDataArea() Export
	
	SaaSOperations.UnlockCurrentDataArea();
	
EndProcedure

// See SaaSReUse.GetDataAreaModel()
//
Function GetDataAreaModel() Export
	
	Return SaaSReUse.GetDataAreaModel();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Message exchange

// See MessageExchange.SendMessage()
//
Procedure SendMessage(MessageChannel, MessageBody, Recipient) Export
	
	MessageExchange.SendMessage(MessageChannel, MessageBody, Recipient);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Users

// See Users.InfobaseUserWithFullAccess()
//
Function InfobaseUserWithFullAccess(User = Undefined,
                                    CheckSystemAdministrationRights = False,
                                    ForPrivilegedMode = True) Export
	
	Return Users.InfobaseUserWithFullAccess(User, CheckSystemAdministrationRights, ForPrivilegedMode);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Integration with 1CBuhphone

// See IntegrationWith1CBuhphone.OnCreateAtServer()
//
Procedure IntegrationWith1CBuhphoneOnCreateAtServer(Item) Export
	
	IntegrationWith1CBuhphone.OnCreateAtServer(Item);
	
EndProcedure



