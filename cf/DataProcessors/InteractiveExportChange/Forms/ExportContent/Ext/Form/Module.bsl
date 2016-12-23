// Optional form parameters:
//
//    SimplifiedMode - Boolean - flag showing that the report will be generated in a simplified form.
//

#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Items.ReportSettingForm.Visible = False;
	
	ThisDataProcessor = ThisObject();
	If IsBlankString(Parameters.AddressOfObject) Then
		ObjectSource = ThisDataProcessor.InitializeThisObject(Parameters.SettingsObject);
	Else
		ObjectSource = ThisDataProcessor.InitializeThisObject(Parameters.AddressOfObject) 
	EndIf;
	
	// We correct selection according to the node scenario, imitate the general selection.
	If ObjectSource.ExportVariant=3 Then
		ObjectSource.ExportVariant = 2;
		
		ObjectSource.ComposerAllDocumentsFilter = Undefined;
		ObjectSource.AllDocumentsFilterPeriod   = Undefined;
		
		DataExchangeServer.FillValueTable(ObjectSource.AdditionalRegistration, ObjectSource.AdditionalRegistrationScriptSite);
	EndIf;
	ObjectSource.AdditionalRegistrationScriptSite.Clear();
		
	ThisObject(ObjectSource);
	
	If Not ValueIsFilled(Object.InfobaseNode) Then
		Text = NStr("en='Data exchange setup is not found.';ru='Настройка обмена данными не найдена.'");
		DataExchangeServer.ShowMessageAboutError(Text, Cancel);
		Return;
	EndIf;
	
	Title = Title + " (" + Object.InfobaseNode + ")";
	BaseNameForForm = ThisDataProcessor.BaseNameForForm();
	
	Parameters.Property("SimplifiedMode", SimplifiedMode);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not GenerateTableDocumentServer() Then
		AttachIdleHandler("Attachable_WaitingForReportGeneration", 3, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	OnCloseAtServer();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers
//

&AtClient
Procedure ResultDetailProcessing(Item, Details, StandardProcessing)
	StandardProcessing = False;
	
	DetailsParameters = FirstLevelDetailsParameters(Details);
	If DetailsParameters <> Undefined Then
		If DetailsParameters.RegistrationObjectMetadataName = DetailsParameters.FullMetadataName Then
			TypeDetails = TypeOf(DetailsParameters.RegistrationObject);
			
			If TypeDetails = Type("Array") Or TypeDetails = Type("ValueList") Then
				// List details
				DetailsParameters.Insert("SettingsObject", Object);
				DetailsParameters.Insert("SimplifiedMode", SimplifiedMode);
				
				OpenForm(BaseNameForForm + "Form.ExportContent", DetailsParameters);
				Return;
			EndIf;
			
			// Object decryption
			FormParameters = New Structure("Key", DetailsParameters.RegistrationObject);
			OpenForm(DetailsParameters.FullMetadataName + ".ObjectForm", FormParameters);

		ElsIf Not IsBlankString(DetailsParameters.ListPresentation) Then
			// Open yourself with new parameters.
			DetailsParameters.Insert("SettingsObject", Object);
			DetailsParameters.Insert("SimplifiedMode", SimplifiedMode);
			
			OpenForm(BaseNameForForm + "Form.ExportContent", DetailsParameters);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers
//

&AtClient
Procedure GenerateReport(Command)
	
	If Not GenerateTableDocumentServer() Then
		AttachIdleHandler("Attachable_WaitingForReportGeneration", 3, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportSettings(Command)
	Items.ReportSettingForm.Check = Not Items.ReportSettingForm.Check;
	Items.SettingsComposerUserSettings.Visible = Items.ReportSettingForm.Check;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
//

&AtClient
Procedure Attachable_ReportGenerateWait()
	
	If BackGroundJobFinished(BackgroundJobID) Then
		ProcessJobExecutionResult();
	Else
		AttachIdleHandler("Attachable_WaitingForReportGeneration", 3, True);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function BackGroundJobFinished(BackgroundJobID)
	
	Return LongActions.JobCompleted(BackgroundJobID);
	
EndFunction

&AtServer
Procedure ProcessJobExecutionResult()
	
	ImportResultReport();
	
	StatePresentation = Items.Result.StatePresentation;
	StatePresentation.Visible = False;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
	
EndProcedure

&AtServer
Function ThisObject(NewObject=Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function GenerateTableDocumentServer()
	
	StopReportGeneration();
	
	JobParameters = New Structure;
	JobParameters.Insert("DataProcessorStructure", ThisObject().ThisObjectInStructureForBackground());
	JobParameters.Insert("FullMetadataName", Parameters.FullMetadataName);
	JobParameters.Insert("Presentation", Parameters.ListPresentation);
	JobParameters.Insert("SimplifiedMode", SimplifiedMode);
	
	BackgroundJobResult = LongActions.ExecuteInBackground(UUID,
		"DataExchangeServer.InteractiveExportChange_FormTableUserDocument",
		JobParameters, NStr("en='Generation of report on the composition of the data to be sent during synchronization';ru='Формирование отчета по составу данных для отправки при синхронизации'"));
	
	BackgroundJobResultAddress = BackgroundJobResult.StorageAddress;
	BackgroundJobID = BackgroundJobResult.JobID;
	
	If BackgroundJobResult.JobCompleted Then
		ImportResultReport();
		Return True;
	Else
		StatePresentation = Items.Result.StatePresentation;
		StatePresentation.Visible                      = True;
		StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
		StatePresentation.Picture                       = PictureLib.LongOperation48;
		StatePresentation.Text                          = NStr("en='Generating the report...';ru='Отчет формируется...'");
		Return False;
	EndIf;
	
EndFunction

&AtServer
Procedure StopReportGeneration()
	
	LongActions.CancelJobExecution(BackgroundJobID);
	If Not IsBlankString(BackgroundJobResultAddress) Then
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	
	BackgroundJobResultAddress = "";
	BackgroundJobID = Undefined;
	
EndProcedure

&AtServer
Procedure ImportResultReport()
	
	ReportData = Undefined;
	If Not IsBlankString(BackgroundJobResultAddress) Then
		ReportData = GetFromTempStorage(BackgroundJobResultAddress);
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	
	StopReportGeneration();
	
	If TypeOf(ReportData)<>Type("Structure") Then
		Return;
	EndIf;
	
	Result = ReportData.SpreadsheetDocument;
	
	ClearDetails();
	DataAddressDetails = PutToTempStorage(ReportData.Details, New UUID);
	SchemaURLComposition   = PutToTempStorage(ReportData.CompositionSchema, New UUID);
	
EndProcedure

&AtServer
Procedure OnCloseAtServer()
	StopReportGeneration();
	ClearDetails();
EndProcedure

&AtServer
Procedure ClearDetails()
	
	If Not IsBlankString(DataAddressDetails) Then
		DeleteFromTempStorage(DataAddressDetails);
	EndIf;
	If Not IsBlankString(SchemaURLComposition) Then
		DeleteFromTempStorage(SchemaURLComposition);
	EndIf;
	
EndProcedure

&AtServer
Function FirstLevelDetailsParameters(Details)
	
	DetailProcessing = New DataCompositionDetailsProcess(
		DataAddressDetails,
		New DataCompositionAvailableSettingsSource(SchemaURLComposition));
	
	MetadataNameField = New DataCompositionField("FullMetadataName");
	Settings = DetailProcessing.DrillDown(Details, MetadataNameField);
	
	DetailsParameters = New Structure("FullMetadataName, ListPresentation, RegistrationObject, RegistrationObjectMetadataName");
	DetailsLevelGroupAnalysis(Settings.Filter, DetailsParameters);
	
	If IsBlankString(DetailsParameters.FullMetadataName) Then
		Return Undefined;
	EndIf;
	
	Return DetailsParameters;
EndFunction

&AtServer
Procedure DetailsLevelGroupAnalysis(Filter, DetailsParameters)
	
	MetadataNameField = New DataCompositionField("FullMetadataName");
	FieldPresentation = New DataCompositionField("ListPresentation");
	FieldObject        = New DataCompositionField("RegistrationObject");
	
	For Each Item IN Filter.Items Do
		If TypeOf(Item)=Type("DataCompositionFilterItemGroup") Then
			DetailsLevelGroupAnalysis(Item, DetailsParameters);
			
		ElsIf Item.LeftValue=MetadataNameField Then
			DetailsParameters.FullMetadataName = Item.RightValue;
			
		ElsIf Item.LeftValue=FieldPresentation Then
			DetailsParameters.ListPresentation = Item.RightValue;
			
		ElsIf Item.LeftValue=FieldObject Then
			RegistrationObject = Item.RightValue;
			DetailsParameters.RegistrationObject = RegistrationObject;
			
			If TypeOf(RegistrationObject) = Type("Array") AND RegistrationObject.Count()>0 Then
				Variant = RegistrationObject[0];
			ElsIf TypeOf(RegistrationObject) = Type("ValueList") AND RegistrationObject.Count()>0 Then
				Variant = RegistrationObject[0].Value;
			Else
				Variant = RegistrationObject;
			EndIf;
			
			Meta = Metadata.FindByType(TypeOf(Variant));
			DetailsParameters.RegistrationObjectMetadataName = ?(Meta = Undefined, Undefined, Meta.FullName());
		EndIf;
		
	EndDo;
EndProcedure

#EndRegion














