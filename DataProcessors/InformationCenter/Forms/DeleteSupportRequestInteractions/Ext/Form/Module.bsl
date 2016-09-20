////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SupportRequestID = Undefined;
	If Parameters.Property("SupportRequestID") Then 
		SupportRequestID = Parameters.SupportRequestID;
	EndIf;
	
	If Parameters.Property("Description") Then 
		Title = Parameters.Description;
	EndIf;
	
	CurrentPageNumber = 1;
	
	ContentFormsRefresh();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS


////////////////////////////////////////////////////////////////////////////////
// TABLE EVENTS HANDLERS InteractionsTable

&AtClient
Procedure InteractionsTableOnActivateRow(Item)
	
	RefreshContentRepresentation(Item.CurrentData.ID);
	
EndProcedure

&AtClient
Procedure SaveFile(Command)
	
	Structure = GetStorageAddressFile(Items.InteractionsTableAttachments.CurrentData.ID);
	If Structure.Address <> Undefined Then 
		GetFile(Structure.Address, Structure.Name, True);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Previous(Command)
	
	ContentFormsRefresh(-1);
	
EndProcedure

&AtClient
Procedure TheFollowing(Command)
	
	ContentFormsRefresh(-1);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	ContentFormsRefresh();
	
EndProcedure

&AtClient
Procedure AddNewMessage(Command)
	
	MessageParameters = GenerateMessageParameters();
	InformationCenterClient.OpenSendingMessageToSupportForm(MessageParameters);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure ContentFormsRefresh(PageOffset = 0)
	
	CurrentPageNumber = CurrentPageNumber + PageOffset;
	
	If SupportRequestID = Undefined Then 
		RaiseServiceDisplayExports();
	EndIf;
	
	Result = GetListAndMessageCountForUserAppeal();
	If Result = Undefined Then 
		RaiseServiceDisplayExports();
	EndIf;
	
	ReflectHeaderItems(Result);
	
	ShowMessageList(Result);
	
EndProcedure

&AtServer
Procedure RaiseServiceDisplayExports()
	
	If SupportRequestID = Undefined Then 
		Raise NStr("en='Service providing request to support is temporarily unavailable.
		|Please, try again later';ru='Сервис по отображению обращений в техподдержку временно недоступен.
		|Пожалуйста, повторите попытку позже'");
	EndIf;
	
EndProcedure

&AtServer
Function GetListAndMessageCountForUserAppeal()
	
	Try
		Proxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Return Proxy.GetMessagesSupportService(SupportRequestID, CurrentPageNumber);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Function GetStorageAddressFile(FileID)
	
	Try
		Proxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Structure = Proxy.GetAttachmaent(FileID);
		Address     =  PutToTempStorage(Structure.binData);
		Return New Structure("Address, Name", Address, Structure.name)
	Except
		EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Procedure ReflectHeaderItems(Result)
	
	MessageCount           = Result.count;
	MessageCountOnPage = Result.countOnPage;
	
	If MessageCount = 0 Then 
		Return;
	EndIf;
	
	Range = GetRange(MessageCountOnPage, MessageCount);
	Items.Range.Title = GetTemplateRange(Range);
	
	ReflectCommandsEnabled(MessageCountOnPage, MessageCount);
	
EndProcedure

&AtServer
Function GetRange(MessageCountOnPage, MessageCount)
	
	Begin = (CurrentPageNumber - 1) * MessageCountOnPage + 1;
	End  = CurrentPageNumber * MessageCountOnPage;
	End  = ?(End > MessageCount, MessageCount, End);
	
	Return New Structure("Beginning, End", Begin, End);
	
EndFunction

&AtServer
Function GetTemplateRange(Range)

	Pattern = "%1 - %2";
	Pattern = StringFunctionsClientServer.PlaceParametersIntoString(Pattern, Range.Begin, Range.End);
	
	Return Pattern;
	
EndFunction

&AtServer
Procedure ReflectCommandsEnabled(SupportRequestsQuantityOnPage, CallCount)
	
	Items.TheFollowing.Enabled  = ?(CurrentPageNumber * SupportRequestsQuantityOnPage < CallCount, True, False);
	Items.Previous.Enabled = ?(CurrentPageNumber > 1, True, False);
	
EndProcedure

&AtServer
Procedure ShowMessageList(Result)
	
	If Result.messageList.Count() = 0 Then 
		Return;
	EndIf;
	
	InteractionsList.Clear();
	
	For Iteration = 0 To Result.messageList.Count() - 1 Do
		
		Message = Result.messageList.Get(Iteration);
		
		Item = InteractionsList.Add();
		
		Item.MessageText        = Message.text;
		Item.PictureTypeMessage = ?(Message.ingoing, PictureLib.IncomingMessage, PictureLib.OutgoingMessage);
		Item.MessageDate         = Message.date;
		Item.HTMLText             = Message.textHTML;
		Item.ID         = Message.ID;
		Item.HTMLAttachments.Add(GetFilesPicturesStructure(Message.filesHTML));
		FillListAttachments(Item, Message.attachments);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillListAttachments(TableRow, Attachments)
	
	For Each Attachment IN Attachments Do 
		NewItem = TableRow.Attachments.Add();
		NewItem.Name           = Attachment.name;
		NewItem.ID = Attachment.id;
	EndDo;
	
EndProcedure

&AtServer
Function GetFilesPicturesStructure(Files)
	
	Structure = New Structure;
	
	For Each FileStructure in Files Do
		Structure.Insert(FileStructure.name, New Picture(FileStructure.binData));
	EndDo;
	
	Return Structure;
	
EndFunction

&AtServer
Procedure RefreshContentRepresentation(ID)
	
	Filter = New Structure("ID", ID);
	RowArray = InteractionsList.FindRows(Filter);
	If RowArray.Count() = 0 Then 
		Return;
	EndIf;
	
	TableRow = RowArray.Get(0);
	
	CurrentMessageContent.SetHTML(TableRow.HTMLText, TableRow.HTMLAttachments.Get(0).Value);
	
EndProcedure

&AtServer
Function GenerateMessageParameters()
	
	SetPrivilegedMode(True);
	
	AdditionalPreferences = New Structure;
	AdditionalPreferences.Insert("SupportRequestID", SupportRequestID);
	
	MessageParameters = New Structure;
	MessageParameters.Insert("FromWhom", InformationCenterServer.DefineUserEmailAddress());
	MessageParameters.Insert("Attachments", InformationCenterServer.GenerateXMLWithTechnicalParameters(AdditionalPreferences));
	MessageParameters.Insert("ShowTheme", False);
	
	Return MessageParameters;
	
EndFunction
















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
