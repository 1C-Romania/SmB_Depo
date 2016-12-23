////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Sort = Items.Sort.ChoiceList.Get(0).Value;
	Filter = Items.Filter.ChoiceList.Get(0).Value;
	CurrentPage = 1;
	UserID = Users.CurrentUser().ServiceUserID;
	
	RequestsListFill();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SendingMessageToSupportService" Or EventName = "InteractionOnContactSeen"  Then 
		AttachIdleHandler("FillRequestsListClient", 0.1, True);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure SortOnChange(Item)
	
	CurrentPage = 1;
	RequestsListFill();
	
EndProcedure

&AtClient
Procedure FilterOnChange(Item)
	
	CurrentPage = 1;
	RequestsListFill();
	
EndProcedure

&AtClient
Procedure TransitionToLeftClick(Item)
	
	CurrentPage = CurrentPage - 1;
	RequestsListFill();
	
EndProcedure

&AtClient
Procedure TransitionToRightClick(Item)
	
	CurrentPage = CurrentPage + 1;
	RequestsListFill();
	
EndProcedure

&AtClient
Procedure ReferencesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ReferencesLabelHasResponse" Then 
		InformationCenterClient.OpenNotSeenInteractions(Item.CurrentData.ID, Item.CurrentData.ListNotSeenInteractions);
	Else
		InformationCenterClient.OpenContactSupport(Item.CurrentData.ID);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ContactCustomerSupport(Command)
	
	InformationCenterClient.OpenFormOpeningMessagesToSupport(True);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure FillRequestsListClient()
	RequestsListFill();
EndProcedure

&AtServer
Procedure RequestsListFill()
	
	Try
		RequestsListPresentation = GetRequestsListPresentation();
		GeneratePage(RequestsListPresentation);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(InformationCenterServer.GetEventNameForEventLogMonitor(), 
		                         EventLogLevel.Error,
		                         ,
		                         ,
		                         ErrorText);
		OutputText = InformationCenterServer.ErrorInformationTextOutputInSupport();
		Raise OutputText;
	EndTry;
	
EndProcedure

&AtServer
Function GetRequestsListPresentation()
	
	WSProxy = InformationCenterServer.GetProxyServicesSupport();
	
	Result = WSProxy.getIncidents(String(UserID), CurrentPage, Filter, Sort);
	
	Return Result;
	
EndFunction

&AtServer
Procedure GeneratePage(RequestsListPresentation)
	
	FillContact(RequestsListPresentation);
	
	FillFooter(RequestsListPresentation);
	
EndProcedure

&AtServer
Procedure FillContact(RequestsListPresentation)
	
	References.Clear();
	For Each RequestObject IN RequestsListPresentation.Incidents Do 
		
		NewAppeal = References.Add();
		NewAppeal.ID = New UUID(RequestObject.Id);
		NewAppeal.Status = RequestObject.Status;
		NewAppeal.Description = ?(IsBlankString(RequestObject.Name), NStr("en='<No theme>';ru='<Без темы>'"), RequestObject.Name);
		NewAppeal.Picture = InformationCenterServer.PictureBySupportRequestState(RequestObject.Status);
		NewAppeal.Date = RequestObject.Date;
		NewAppeal.Number = RequestObject.Number;
		NewAppeal.NotSeenInteractionsQuantity = RequestObject.UnreviewedInteractions.Count();
		If NewAppeal.NotSeenInteractionsQuantity <> 0 Then 
			ExplanationHasResponse = ?(NewAppeal.NotSeenInteractionsQuantity = 1, "", " (" + String(NewAppeal.NotSeenInteractionsQuantity) + ")");
			HasResponse = ?(NewAppeal.NotSeenInteractionsQuantity = 1, NStr("en='Unread';ru='Не прочитано'"), NStr("en='Unread';ru='Не прочитано'"));
			NewAppeal.LabelHasResponse = HasResponse + ExplanationHasResponse;
			For Each UnviewedInteraction IN RequestObject.UnreviewedInteractions Do 
				ListValue = New Structure;
				ListValue.Insert("Subject", UnviewedInteraction.Name);
				ListValue.Insert("Date", UnviewedInteraction.Date);
				ListValue.Insert("Description", UnviewedInteraction.Description);
				ListValue.Insert("ID", New UUID(UnviewedInteraction.Id));
				ListValue.Insert("Type", UnviewedInteraction.Type);
				ListValue.Insert("Incoming", UnviewedInteraction.Incoming);
				NewListItem = NewAppeal.ListNotSeenInteractions.Add(ListValue);
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillFooter(RequestsListPresentation)
	
	HasPagesBefore = (CurrentPage > 1);
	HasPageAfter = RequestsListPresentation.IsStill;
	
	Items.TransitionToLeft.Hyperlink = HasPagesBefore;
	Items.TransitionToLeft.Picture = ?(HasPagesBefore, PictureLib.GoToLeftActive, PictureLib.GoToLeftNotActive);
	Items.TransitionToRight.Picture = ?(HasPageAfter, PictureLib.GoToRightActive, PictureLib.GoToRightNotActive);
	Items.TransitionToRight.Hyperlink = HasPageAfter;
	Items.CurrentPage.Title = CurrentPage;
	
EndProcedure





























