////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	InteractionsIdentifier = Parameters.InteractionsIdentifier;
	SupportRequestID = Parameters.SupportRequestID;
	TypeInteractions = Parameters.TypeInteractions;
	Incoming = Parameters.Incoming;
	UserID = Users.CurrentUser().ServiceUserID;
	Seen = Parameters.Seen;
	
	FillInteraction();
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not Seen Then 
		Notify("InteractionOnContactSeen");
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure FilesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "FilesPresentation" Or Field.Name = "FilesPicture" Then 
		Result = GetFileNameAndFileStorageAddress(Item.CurrentData.ID);
		GetFile(Result.StorageAddress, Result.Name);
	EndIf;
	
EndProcedure

&AtClient
Procedure Answer(Command)
	
	InformationCenterClient.OpenFormOpeningMessagesToSupport(False, SupportRequestID);
	
EndProcedure

&AtClient
Procedure GoToSupportRequest(Command)
	
	InformationCenterClient.OpenContactSupport(SupportRequestID);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure FillInteraction()
	
	Try
		DataByInteraction = GetDataOnInteraction();
		FillFormItems(DataByInteraction);
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
Function GetDataOnInteraction()
	
	WSProxy = InformationCenterServer.GetProxyServicesSupport();
	
	Result = WSProxy.getInteraction(String(UserID), String(InteractionsIdentifier), TypeInteractions, Incoming);
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillFormItems(DataByInteraction)
	
	ThisForm.Title = DataByInteraction.Name;
	
	If DataByInteraction.Type = "PhoneCall" Then
		
		Items.Content.Visible = False;
		Items.Files.Visible = False;
		
		Return;
		
	EndIf;
	
	HTMLText = DataByInteraction.HTMLText;
	
	// Place pictures in the temporary storage
	For Each DD IN DataByInteraction.HTMLFiles Do 
		Picture = New Picture(DD.Data);
		StorageAddress = PutToTempStorage(Picture);
		HTMLText = StrReplace(HTMLText, DD.Name, StorageAddress);
	EndDo;
	
	Content = HTMLText;
	
	// Display files
	
	Files.Clear();
	Items.Files.Visible = (DataByInteraction.Files.Count() <> 0);
	For Each CurrentFile IN DataByInteraction.Files Do 
		NewItem = Files.Add();
		NewItem.Presentation = CurrentFile.Name + "." + CurrentFile.Extension + " (" + Round(CurrentFile.Size / 1024, 2) + NStr("en=' Kb';ru=' Кб'") + ")";
		NewItem.Picture = FileFunctionsServiceClientServer.GetFileIconIndex(CurrentFile.Extension);
		NewItem.ID = New UUID(CurrentFile.Id);
	EndDo;
	
EndProcedure

&AtServer
Function GetFileNameAndFileStorageAddress(FileID)
	
	ReturnValue = New Structure;
	ReturnValue.Insert("StorageAddress", "");
	ReturnValue.Insert("Name", "");
	
	Try
		WSProxy = InformationCenterServer.GetProxyServicesSupport();
		Result = WSProxy.getInteractionFile(String(UserID), String(InteractionsIdentifier), String(FileID), TypeInteractions, Incoming);
		ReturnValue.StorageAddress = PutToTempStorage(Result.Data, UUID);
		ReturnValue.Name = Result.Name + "." + Result.Extension;
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
	
	Return ReturnValue;
	
EndFunction











