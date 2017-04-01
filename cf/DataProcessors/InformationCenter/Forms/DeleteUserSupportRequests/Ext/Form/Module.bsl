////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	UserID = Users.CurrentUser().ServiceUserID;
	SetPrivilegedMode(False);
	
	CurrentPageNumber = 1;
	
	DefaultFilterValue = Items.FilterOfCalls.ChoiceList.Get(0).Value;
	FilterOfCalls            = DefaultFilterValue;
	
	ContentFormsRefresh();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure SupportServiceRequestsFilterOnChange(Item)
	
	ContentFormsRefresh();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// TABLE EVENTS HANDLERS Support requests list

&AtClient
Procedure RequestsListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure();
	FormParameters.Insert("SupportRequestID", Item.CurrentData.ID);
	FormParameters.Insert("Description",           Item.CurrentData.Description);
	
	OpenForm("DataProcessor.InformationCenter.Form.DeleteSupportRequestInteractions", FormParameters);
	
	SetSignProsmotrennosti(Item.CurrentData.ID);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure TheFollowing(Command)
	
	ContentFormsRefresh(+1);
	
EndProcedure

&AtClient
Procedure Previous(Command)
	
	ContentFormsRefresh(-1);
	
EndProcedure

&AtClient
Procedure ContactCustomerSupport(Command)
	
	MessageParameters = GenerateMessageParameters();
	InformationCenterClient.OpenSendingMessageToSupportForm(MessageParameters);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	ContentFormsRefresh();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure ContentFormsRefresh(PageOffset = 0)
	
	CurrentPageNumber = CurrentPageNumber + PageOffset;
	
	Result = GetListAndCountRequestsUser();
	If Result = Undefined Then 
		Raise NStr("en='Service providing request to support is temporarily unavailable.
		|Please, try again later';ru='Сервис по отображению обращений в техподдержку временно недоступен.
		|Пожалуйста, повторите попытку позже'");
	EndIf;
	
	ReflectHeaderItems(Result);
	
	OutputRequestsList(Result);
	
EndProcedure

&AtServer
Function GetListAndCountRequestsUser()
	
	ShowAllSupportRequests = ?(FilterOfCalls = Items.FilterOfCalls.ChoiceList.Get(0).Value, True, False);
	
	Try
		Proxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_2();
		Return Proxy.GetTicketsSupportService(UserID, CurrentPageNumber, ShowAllSupportRequests);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Procedure ReflectHeaderItems(Result)
	
	CallCount           = Result.count;
	SupportRequestsQuantityOnPage = Result.countOnPage;
	
	If CallCount = 0 Then 
		Return;
	EndIf;
	
	Range = GetSupportRequestsRange(SupportRequestsQuantityOnPage, CallCount);
	Items.Range.Title = GetTemplateRangeExports(Range);
	
	ReflectCommandsEnabled(SupportRequestsQuantityOnPage, CallCount);
	
EndProcedure

&AtServer
Function GetSupportRequestsRange(SupportRequestsQuantityOnPage, CallCount)
	
	Begin = (CurrentPageNumber - 1) * SupportRequestsQuantityOnPage + 1;
	End  = CurrentPageNumber * SupportRequestsQuantityOnPage;
	End  = ?(End > CallCount, CallCount, End);
	
	Return New Structure("Beginning, End", Begin, End);
	
EndFunction

&AtServer
Function GetTemplateRangeExports(Range)

	Pattern = "%1 - %2";
	Pattern = StringFunctionsClientServer.SubstituteParametersInString(Pattern, Range.Begin, Range.End);
	
	Return Pattern;
	
EndFunction

&AtServer
Procedure ReflectCommandsEnabled(SupportRequestsQuantityOnPage, CallCount)
	
	Items.TheFollowing.Enabled  = ?(CurrentPageNumber * SupportRequestsQuantityOnPage < CallCount, True, False);
	Items.Previous.Enabled = ?(CurrentPageNumber > 1, True, False);
	
EndProcedure

&AtServer
Procedure OutputRequestsList(Result)
	
	If Result.ticketList.Count() = 0 Then 
		Return;
	EndIf;
	
	RequestsList.Clear();
	
	For Iteration = 0 To Result.ticketList.Count() - 1 Do
		
		Appeal = Result.ticketList.Get(Iteration);
		
		Item = RequestsList.Add();
		
		Item.Status              = Appeal.stage;
		Item.Date                = Appeal.date;
		Item.Description        = Appeal.name;
		Item.Code                 = Appeal.number;
		Item.ID       = Appeal.id;
		Item.HasNewMessages = Appeal.havingNewMessages;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetSignProsmotrennosti(ID)
	
	Filter = New Structure("ID", ID);
	RowArray = RequestsList.FindRows(Filter);
	If RowArray = 0 Then 
		Return;
	EndIf;
	
	RowArray.Get(0).HasNewMessages = False;
	
EndProcedure

&AtServer
Function GenerateMessageParameters()
	
	SetPrivilegedMode(True);
	
	MessageParameters = New Structure;
	MessageParameters.Insert("FromWhom",   InformationCenterServer.DefineUserEmailAddress());
	MessageParameters.Insert("Text",    InformationCenterServer.GenerateTextTemplateToTechnicalSupport());
	MessageParameters.Insert("Attachments", InformationCenterServer.GenerateXMLWithTechnicalParameters());
	
	Return MessageParameters;
	
EndFunction

















