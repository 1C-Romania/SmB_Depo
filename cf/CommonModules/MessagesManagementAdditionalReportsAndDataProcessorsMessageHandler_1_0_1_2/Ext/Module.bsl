////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNELS HANDLER FOR VERSION 1.0.1.2 OF MESSAGE INTERFACE FOR ADDITIONAL REPORTS AND DATA PROCESSORS MANAGEMENT
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns namespace for message interface version
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Management/" + Version();
	
EndFunction

// Returns a message interface version served by the handler
Function Version() Export
	
	Return "1.0.1.2";
	
EndFunction

// Returns default type for version messages
Function BaseType() Export
	
	Return MessagesSaaSreuse.TypeBody();
	
EndFunction

// Processes incoming messages in service model
//
// Parameters:
//  Message - ObjectXDTO,
//  incoming message, Sender - ExchangePlanRef.Messaging, exchange plan
//  node, corresponding to message sender MessageProcessed - Boolean, a flag showing that the message is successfully processed. The value of
//    this parameter shall be set as equal to True if the message was successfully read in this handler
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageHandled) Export
	
	MessageHandled = True;
	
	Dictionary = MessagesManagementAdditionalReportsAndDataProcessorsInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageSetAdditionalReportOrProcessing(Package()) Then
		SetAdditionalReportOrProcessing(Message, Sender);
	ElsIf MessageType = Dictionary.MessageDeleteAdditionalReportOrProcessing(Package()) Then
		DeleteAdditionalReportOrProcessing(Message, Sender);
	ElsIf MessageType = Dictionary.MessageDisableAdditionalReportOrProcessing(Package()) Then
		DisableAdditionalReportOrProcessing(Message, Sender);
	ElsIf MessageType = Dictionary.MessageEnableAdditionalReportOrProcessing(Package()) Then
		EnableAdditionalReportOrProcessing(Message, Sender);
	ElsIf MessageType = Dictionary.MessageRecallAdditionalReportOrProcessing(Package()) Then
		RecallAdditionalReportOrProcessing(Message, Sender);
	ElsIf MessageType = Dictionary.MessageSetModeForAdditionalReportExecutionOrProcessingInDataArea(Package()) Then
		SetModeForAdditionalReportConnectionOrDataAreaProcessor(Message, Sender);
	Else
		MessageHandled = False;
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Procedure SetAdditionalReportOrProcessing(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	
	Try
	
		CommandSettings = New ValueTable();
		CommandSettings.Columns.Add("ID");
		CommandSettings.Columns.Add("QuickAccess");
		CommandSettings.Columns.Add("Schedule");
		
		If ValueIsFilled(MessageBody.CommandSettings) Then
			
			For Each CommandSettings IN MessageBody.CommandSettings Do
				
				CommandSettings = CommandSettings.Add();
				CommandSettings.ID = CommandSettings.Id;
				
				If CommandSettings.Settings <> Undefined Then
					
					ArrayOfIDs = New Array;
					For Each UserGUID IN CommandSettings.Settings.UsersFastAccess Do
						ArrayOfIDs.Add(UserGUID);
					EndDo;
					
					CommandSettings.QuickAccess = ArrayOfIDs;
					
					If CommandSettings.Settings.Schedule <> Undefined Then
						
						CommandSettings.Schedule = XDTOSerializer.ReadXDTO(CommandSettings.Settings.Schedule);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		SectionsSettings = New ValueTable();
		SectionsSettings.Columns.Add("Section");
		
		PrescriptionSettings = New ValueTable();
		PrescriptionSettings.Columns.Add("ObjectDestination");
		
		SettingsLocationOfCommands = New Structure();
		
		If ValueIsFilled(MessageBody.Assignments) Then
			
			For Each Assignment IN MessageBody.Assignments Do
				
				If Assignment.Type() = AdditionalReportsAndDataProcessorsSaaSManifestInterface.SectionPrescriptionType(ManifestPackage()) Then
					
					For Each AssignmentObject IN Assignment.Objects Do
						
						SectionRow = SectionsSettings.Add();
						If AssignmentObject.ObjectName = AdditionalReportsAndDataProcessorsClientServer.DesktopID() Then
							SectionRow.Section = Catalogs.MetadataObjectIDs.EmptyRef();
						Else
							SectionRow.Section = CommonUse.MetadataObjectID(AssignmentObject.ObjectName);
						EndIf;
						
					EndDo;
					
				ElsIf Assignment.Type() = AdditionalReportsAndDataProcessorsSaaSManifestInterface.TypePurposeCatalogsAndDocuments(ManifestPackage()) Then
					
					For Each AssignmentObject IN Assignment.Objects Do
						
						PrescriptionString = PrescriptionSettings.Add();
						PrescriptionString.ObjectDestination = CommonUse.MetadataObjectID(
							AssignmentObject.ObjectName);
						
					EndDo;
					
					SettingsLocationOfCommands.Insert("UseForListForm",
						Assignment.UseInListsForms);
					SettingsLocationOfCommands.Insert("UseForObjectForm",
						Assignment.UseInObjectsForms);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		VariantsSettings = New ValueTable();
		VariantsSettings.Columns.Add("Key", New TypeDescription("String"));
		VariantsSettings.Columns.Add("Placement", New TypeDescription("Array"));
		VariantsSettings.Columns.Add("Presentation", New TypeDescription("String"));
		If MessageBody.ReportVariants <> Undefined Then
			
			For Each ReportVariant IN MessageBody.ReportVariants Do
				
				VariantSetting = VariantsSettings.Add();
				VariantSetting.Key = ReportVariant.VariantKey;
				VariantSetting.Presentation = ReportVariant.Representation;
				
				Placement = New Array;
				For Each ReportVariantAssignment IN ReportVariant.Assignments Do
					
					Section = CommonUse.MetadataObjectID(
						ReportVariantAssignment.ObjectName);
					Important = False;
					SeeAlso = False;
					If ReportVariantAssignment.Importance = "High" Then
						Important = True;
					ElsIf ReportVariantAssignment.Importance = "Low" Then
						SeeAlso = True;
					EndIf;
					PlacingItem = New Structure("Section,Important,SeeAlso", Section, Important, SeeAlso);
					Placement.Add(PlacingItem);
					
				EndDo;
				
				VariantSetting.Placement = Placement;
				
			EndDo;
			
		EndIf;
		
		InstallationDetails = New Structure(
			"ID,Presentation,Installation",
			MessageBody.Extension,
			MessageBody.Representation,
			MessageBody.Installation);
		
		MessagesManagementAdditionalReportsAndDataProcessorsImplementation.SetAdditionalReportOrProcessing(
			InstallationDetails, CommandSettings, SettingsLocationOfCommands, SectionsSettings,
			PrescriptionSettings, VariantsSettings, MessageBody.InitiatorServiceID);
		
	Except
		
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		SuppliedDataProcessor = Catalogs.SuppliedAdditionalReportsAndDataProcessors.GetRef(MessageBody.Extension);
		AdditionalReportsAndDataProcessorsSaaS.ProcessAdditionalInformationProcessorSettingToDataAreaError(
			SuppliedDataProcessor, MessageBody.Installation, ErrorMessage);
		
	EndTry;
	
EndProcedure

Procedure DeleteAdditionalReportOrProcessing(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesManagementAdditionalReportsAndDataProcessorsImplementation.DeleteAdditionalReportOrProcessing(
		MessageBody.Extension, MessageBody.Installation);
	
EndProcedure

Procedure DisableAdditionalReportOrProcessing(Val Message, Val Sender)
	
	If Message.Body.Reason = "LockByOwner" Then
		ShutdownCause = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.BlockingByOwner;
	ElsIf Message.Body.Reason = "LockByProvider" Then
		ShutdownCause = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS.BlockAdministratorService;
	EndIf;
	
	MessagesManagementAdditionalReportsAndDataProcessorsImplementation.DisableAdditionalReportOrProcessing(
		Message.Body.Extension, ShutdownCause);
	
EndProcedure

Procedure EnableAdditionalReportOrProcessing(Val Message, Val Sender)
	
	MessagesManagementAdditionalReportsAndDataProcessorsImplementation.EnableAdditionalReportOrProcessing(
		Message.Body.Extension);
	
EndProcedure

Procedure RecallAdditionalReportOrProcessing(Val Message, Val Sender)
	
	MessagesManagementAdditionalReportsAndDataProcessorsImplementation.RecallAdditionalReportOrProcessing(
		Message.Body.Extension);
	
EndProcedure

Procedure SetModeForAdditionalReportConnectionOrDataAreaProcessor(Val Message, Val Sender)
	
	MessagesManagementAdditionalReportsAndDataProcessorsImplementation.SetModeForAdditionalReportConnectionOrDataAreaProcessor(
		Message.Body.Extension, Message.Body.Installation, Message.Body.SecurityProfile);
	
EndProcedure

Function ManifestPackage()
	
	Return AdditionalReportsAndDataProcessorsSaaSManifestInterface.Package("1.0.0.1");
	
EndFunction