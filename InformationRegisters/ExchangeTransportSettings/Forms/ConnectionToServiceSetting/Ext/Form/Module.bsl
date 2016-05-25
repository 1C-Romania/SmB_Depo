
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DataExchangeServer.CheckExchangesAdministrationPossibility();
	
	SetPrivilegedMode(True);
	
	AddressForAccountPasswordRecovery = Parameters.AddressForAccountPasswordRecovery;
	AutomaticSynchronizationSetting = Parameters.AutomaticSynchronizationSetting;
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.AccessToInternetParameters.Visible = True;
	Else
		Items.AccessToInternetParameters.Visible = False;
	EndIf;
	
	If Not IsBlankString(Record.WSUserName) Then
		
		User = Users.FindByName(Record.WSUserName);
		
	EndIf;
	
	For Each UserSynchronization IN UsersSynchronizationData() Do
		
		Items.User.ChoiceList.Add(UserSynchronization.User, UserSynchronization.Presentation);
		
	EndDo;
	
	Items.PasswordForgotten.Visible = Not IsBlankString(AddressForAccountPasswordRecovery);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	CheckConnectionToService(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If AutomaticSynchronizationSetting Then
		
		Notify("Record_SetUpTransportExchange",
			New Structure("AutomaticSynchronizationSetting"));
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.WSRememberPassword = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PasswordForgotten(Command)
	
	DataExchangeClient.OnInstructionOpenHowToChangeDataSynchronizationPassword(AddressForAccountPasswordRecovery);
	
EndProcedure

&AtClient
Procedure AccessToInternetParameters(Command)
	
	DataExchangeClient.OpenProxyServerParameterForm();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure CheckConnectionToService(Cancel)
	
	SetPrivilegedMode(True);
	
	// Define the user name.
	PropertiesUser = Undefined;
	
	Users.ReadIBUser(
		CommonUse.ObjectAttributeValue(User, "InfobaseUserID"),
		PropertiesUser);
	If PropertiesUser <> Undefined Then
		Record.WSUserName = PropertiesUser.Name
	EndIf;
	
	// Check the connection to the correspondent.
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	FillPropertyValues(ConnectionParameters, Record);
	
	UserMessage = "";
	If Not DataExchangeServer.IsConnectionToCorrespondent(Record.Node, ConnectionParameters, UserMessage) Then
		CommonUseClientServer.MessageToUser(UserMessage,, "Record.WSPassword",, Cancel);
	EndIf;
	
EndProcedure

&AtServer
Function UsersSynchronizationData()
	
	Result = New ValueTable;
	Result.Columns.Add("User"); // Type: CatalogRef.Users
	Result.Columns.Add("Presentation");
	
	QueryText =
	"SELECT
	|	Users.Ref AS User,
	|	Users.Description AS Presentation,
	|	Users.InfobaseUserID AS InfobaseUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Not Users.DeletionMark
	|	AND Not Users.NotValid
	|	AND Not Users.Service
	|
	|ORDER BY
	|	Users.Description";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ValueIsFilled(Selection.InfobaseUserID) Then
			
			IBUser = InfobaseUsers.FindByUUID(Selection.InfobaseUserID);
			
			If IBUser <> Undefined
				AND DataExchangeServer.DataSynchronizationIsEnabled(IBUser) Then
				
				FillPropertyValues(Result.Add(), Selection);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
