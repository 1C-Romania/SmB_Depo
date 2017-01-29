
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.SpreadsheetDocument <> Undefined Then
		CustomizableTemplate = Parameters.SpreadsheetDocument;
	EndIf;
	
	MetadataObjectTemplateName = Parameters.MetadataObjectTemplateName;
	
	NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(MetadataObjectTemplateName, ".");
	TemplateName = NameParts[NameParts.UBound()];
	
	OwnerName = "";
	For PartNumber = 0 To NameParts.UBound()-1 Do
		If Not IsBlankString(OwnerName) Then
			OwnerName = OwnerName + ".";
		EndIf;
		OwnerName = OwnerName + NameParts[PartNumber];
	EndDo;
	
	TemplateType = Parameters.TemplateType;
	TemplatePresentation = TemplatePresentation();
	TemplateFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(TemplatePresentation) + "." + Lower(TemplateType);
	
	If Parameters.OnlyOpening Then
		Title = NStr("en='Print form template opening';ru='Открытие макета печатной формы'");
	EndIf;
	
	TypeClient = ?(CommonUseClientServer.ThisIsWebClient(), "", "Not") + "WebClient";
	WindowOptionsKey = TypeClient + Upper(TemplateType);
	
	If Not CommonUseClientServer.ThisIsWebClient() AND TemplateType = "MXL" Then
		Items.DoesLabelChangesNotWebClient.Title = NStr("en='After entering necessary changes into the templates click the ""Complete update"" button';ru='После внесения необходимых изменений в макет нажмите на кнопку ""Завершить изменение""'");
	EndIf;
	
	SetApplicationNameForTemplateOpening();
	
	Items.Dialog.CurrentPage = Items["PageImportToComputer" + TypeClient];
	Items.CommandBar.CurrentPage = Items.ExportPanel;
	Items.ButtonChange.DefaultButton = True;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	#If Not WebClient Then
		If Parameters.OnlyOpening Then
			Cancel = True;
		EndIf;
		If Parameters.OnlyOpening Or TemplateType = "MXL" Then
			OpenTemplate();
		EndIf;
	#EndIf
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not IsBlankString(TemporaryFolder) Then
		DeleteFiles(TemporaryFolder);
	EndIf;
	
	EventName = "RefusalToChangeLayout";
	If TemplateIsImported Then
		EventName = "Record_PrintLayouts";
	EndIf;
	
	Notify(EventName, New Structure("MetadataObjectTemplateName", MetadataObjectTemplateName), ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure RefToApplicationPageClick(Item)
	GotoURL(ApplicationAddressForTemplateOpening);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Change(Command)
	OpenTemplate();
	If Parameters.OnlyOpening Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure CompleteChanging(Command)
	
	#If WebClient Then
		NotifyDescription = New NotifyDescription("PutFileEnd", ThisObject);
		BeginPutFile(NOTifyDescription, FileURLTemplateInTemporaryStorage, TemplateFileName);
	#Else
		If Lower(TemplateType) = "mxl" Then
			CustomizableTemplate.Hide();
			FileURLTemplateInTemporaryStorage = PutToTempStorage(CustomizableTemplate);
			TemplateIsImported = True;
		Else
			File = New File(PathToTemplateFile);
			If File.Exist() Then
				BinaryData = New BinaryData(PathToTemplateFile);
				FileURLTemplateInTemporaryStorage = PutToTempStorage(BinaryData);
				TemplateIsImported = True;
			EndIf;
		EndIf;
		WriteTemplateAndClose();
	#EndIf
	
EndProcedure


&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetApplicationNameForTemplateOpening()
	
	ApplicationNameForOpeningTemplate = "";
	
	FileType = Lower(TemplateType);
	If FileType = "mxl" Then
		ApplicationNameForOpeningTemplate = NStr("en='1C:Enterprise - Work with files';ru='1С:Предприятие - Работа с файлами'");
		ApplicationAddressForTemplateOpening = "http://1c-dn.com/developer_tools/fileworkshop/";
	ElsIf FileType = "doc" Then
		ApplicationNameForOpeningTemplate = NStr("en='Microsoft Word';ru='Microsoft Word'");
		ApplicationAddressForTemplateOpening = "http://office.microsoft.com/en-us/word";
	ElsIf FileType = "odt" Then
		ApplicationNameForOpeningTemplate = NStr("en='OpenOffice Writer';ru='OpenOffice Writer'");
		ApplicationAddressForTemplateOpening = "http://www.openoffice.org/product/writer.html";
	EndIf;
	
	InfoForFilling = New Structure;
	InfoForFilling.Insert("TemplateName", TemplatePresentation);
	InfoForFilling.Insert("ApplicationName", ApplicationNameForOpeningTemplate);
	InfoForFilling.Insert("ActionsDetails", ?(Parameters.OnlyOpening, NStr("en='opening';ru='открытия'"), NStr("en='modification';ru='внесения изменений'")));
	
	FilledItems = New Array;
	FilledItems.Add(Items.RefsOnApplicationPageBeforeExportingWebClient);
	FilledItems.Add(Items.RefsOnPageBeforeImportingApplicationNotWebClient);
	FilledItems.Add(Items.ReferenceToApplicationPageCompletionChangesWebClient);
	FilledItems.Add(Items.ReferenceToApplicationPageCompletionChangesNotWebClient);
	FilledItems.Add(Items.LabelTemplateProgramBeforeExportingWebClient);
	FilledItems.Add(Items.LabelBeforeExportingTemplateApplicationNotWebClient);
	FilledItems.Add(Items.LabelCompletionChangesWebClient);
	FilledItems.Add(Items.DoesLabelChangesNotWebClient);
	
	For Each Item IN FilledItems Do
		Item.Title = StringFunctionsClientServer.SubstituteParametersInStringByName(Item.Title, InfoForFilling);
	EndDo;
	
	VisibleReferencesToApplicationPage = CommonUseClientServer.ThisIsWebClient() Or FileType <> "mxl";
	Items.RefsOnApplicationPageBeforeExportingWebClient.Visible = VisibleReferencesToApplicationPage;
	Items.RefsOnPageBeforeImportingApplicationNotWebClient.Visible = VisibleReferencesToApplicationPage;
	Items.ReferenceToApplicationPageCompletionChangesWebClient.Visible = VisibleReferencesToApplicationPage;
	Items.ReferenceToApplicationPageCompletionChangesNotWebClient.Visible = VisibleReferencesToApplicationPage;
	
	Items.LabelBeforeExportingTemplateApplicationNotWebClient.Visible = FileType <> "mxl";
	
	Items.PageImportToComputerWebClient.Visible = CommonUseClientServer.ThisIsWebClient();
	Items.PageImportToDatabaseWebClient.Visible = CommonUseClientServer.ThisIsWebClient();
	Items.PageImportToComputerNotWebClient.Visible = Not CommonUseClientServer.ThisIsWebClient();
	Items.PageImportToDatabaseNotWebClient.Visible = Not CommonUseClientServer.ThisIsWebClient();
	
EndProcedure

&AtServer
Function TemplatePresentation()
	
	Result = TemplateName;
	
	Owner = Metadata.FindByFullName(OwnerName);
	If Owner <> Undefined Then
		Template = Owner.Templates.Find(TemplateName);
		If Template <> Undefined Then
			Result = Template.Synonym;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure OpenTemplate()
	#If WebClient Then
		OpenTemplateWebClient();
	#Else
		OpenTemplateThinClient();
	#EndIf
EndProcedure

&AtClient
Procedure OpenTemplateThinClient()
	
#If Not WebClient Then
	Template = PrintedFormsTemplate(MetadataObjectTemplateName);
	TemporaryFolder = GetTempFileName();
	CreateDirectory(TemporaryFolder);
	PathToTemplateFile = CommonUseClientServer.AddFinalPathSeparator(TemporaryFolder) + TemplateFileName;
	
	If TemplateType = "MXL" Then
		If Parameters.OnlyOpening Then
			Template.ReadOnly = True;
			Template.Show(TemplatePresentation,,True);
		Else
			Template.Write(PathToTemplateFile);
			Template.Show(TemplatePresentation, PathToTemplateFile, True);
			
			CustomizableTemplate = Template;
		EndIf;
	Else
		Template.Write(PathToTemplateFile);
		If Parameters.OnlyOpening Then
			TemplateFile = New File(PathToTemplateFile);
			TemplateFile.SetReadOnly(True);
		EndIf;
		RunApp(PathToTemplateFile);
	EndIf;
	
	GoToFinishChangePage();
#EndIf
	
EndProcedure

&AtClient
Procedure OpenTemplateWebClient()
	GetFile(PlaceTemplateToTemporaryStorage(), TemplateFileName);
	GoToFinishChangePage();
EndProcedure

&AtServer
Function PlaceTemplateToTemporaryStorage()
	
	Return PutToTempStorage(TemplateBinaryData());
	
EndFunction

&AtServer
Function TemplateBinaryData()
	
	TemplateData = CustomizableTemplate;
	If CustomizableTemplate.TableHeight = 0 Then
		TemplateData = PrintManagement.PrintedFormsTemplate(MetadataObjectTemplateName);
	EndIf;
	
	If TypeOf(TemplateData) = Type("SpreadsheetDocument") Then
		TempFileName = GetTempFileName();
		TemplateData.Write(TempFileName);
		TemplateData = New BinaryData(TempFileName);
		DeleteFiles(TempFileName);
	EndIf;
	
	Return TemplateData;
	
EndFunction

&AtClient
Procedure GoToFinishChangePage()
	Items.Dialog.CurrentPage = Items["PageImportToDatabase" + TypeClient];
	Items.CommandBar.CurrentPage = Items.PanelEndChanging;
	Items.ButtonEndChanging.DefaultButton = True;
EndProcedure

&AtServer
Function TemplateFromTemporaryStorage()
	Template = GetFromTempStorage(FileURLTemplateInTemporaryStorage);
	If Lower(TemplateType) = "mxl" AND TypeOf(Template) <> Type("SpreadsheetDocument") Then
		TempFileName = GetTempFileName();
		Template.Write(TempFileName);
		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.Read(TempFileName);
		Template = SpreadsheetDocument;
		DeleteFiles(TempFileName);
	EndIf;
	Return Template;
EndFunction

&AtServer
Procedure WriteTemplate(Template)
	Record = InformationRegisters.UserPrintTemplates.CreateRecordManager();
	Record.Object = OwnerName;
	Record.TemplateName = TemplateName;
	Record.Use = True;
	Record.Template = New ValueStorage(Template, New Deflation(9));
	Record.Write();
EndProcedure

&AtServerNoContext
Function PrintedFormsTemplate(MetadataObjectTemplateName)
	Return PrintManagement.PrintedFormsTemplate(MetadataObjectTemplateName);
EndFunction

&AtClient
Procedure PutFileEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	TemplateIsImported = Result;
	FileURLTemplateInTemporaryStorage = Address;
	TemplateFileName = SelectedFileName;

	WriteTemplateAndClose();
	
EndProcedure

&AtClient
Procedure WriteTemplateAndClose()
	Template = Undefined;
	If TemplateIsImported Then
		Template = TemplateFromTemporaryStorage();
		If Not ValueIsFilled(Parameters.SpreadsheetDocument) Then
			WriteTemplate(Template);
		EndIf;
	EndIf;
	
	Close(Template);
EndProcedure

#EndRegion
