////////////////////////////////////////////////////////////////////////////////
// Subsystem "Print".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Generates and displays the print forms.
// 
// Parameters:
//  PrintManagerName - String - printing manager for printed objects;
//  TemplateNames       - String - identifiers of print forms;
//  ObjectsArray     - Refs, Array - print objects;
//  FormOwner      - ManagedForm - form from which the printing is executed;
//  PrintParameters    - Structure - random parameters for sending to printing manager.
//
Procedure ExecutePrintCommand(PrintManagerName, TemplateNames, ObjectsArray, FormOwner, PrintParameters = Undefined) Export
	
	// Check the quantity of objects.
	If Not CheckQuantityOfPassedObjects(ObjectsArray) Then
		Return;
	EndIf;
	
	// Get uniqueness key of opened form.
	UniqueKey = String(New UUID);
	
	OpenParameters = New Structure("PrintManagerName,TemplateNames,CommandParameter,PrintParameters");
	OpenParameters.PrintManagerName = PrintManagerName;
	OpenParameters.TemplateNames		 = TemplateNames;
	OpenParameters.CommandParameter	 = ObjectsArray;
	OpenParameters.PrintParameters	 = PrintParameters;
	
	// Open the form for documents printing.
	OpenForm("CommonForm.PrintingDocuments", OpenParameters, FormOwner, UniqueKey);
	
EndProcedure

// Generates and sends print forms to printer.
//
// Parameters:
//  PrintManagerName - String - printing manager for printed objects;
//  TemplateNames       - String - identifiers of print forms;
//  ObjectsArray     - Refs, Array - print objects;
//  FormOwner      - ManagedForm - form from which the printing is executed;
//  PrintParameters    - Structure - random parameters for sending to printing manager.
//
Procedure ExecutePrintCommandToPrinter(PrintManagerName, TemplateNames, ObjectsArray, PrintParameters = Undefined) Export

	// Check the quantity of objects.
	If Not CheckQuantityOfPassedObjects(ObjectsArray) Then
		Return;
	EndIf;
	
	// Generate tabular documents.
#If ThickClientOrdinaryApplication Then
	PrintForms = PrintManagementServerCall.GeneratePrintFormsForQuickPrintOrdinaryApplication(
			PrintManagerName, TemplateNames, ObjectsArray, PrintParameters);
	If Not PrintForms.Cancel Then
		PrintObjects = New ValueList;
		DocumentsTable = GetFromTempStorage(PrintForms.Address);
		For Each PrintObject IN PrintForms.PrintObjects Do
			PrintObjects.Add(PrintObject.Value, PrintObject.Key);
		EndDo;
		PrintForms.PrintObjects = PrintObjects;
	EndIf;
#Else
	PrintForms = PrintManagementServerCall.GeneratePrintFormsForQuickPrint(
			PrintManagerName, TemplateNames, ObjectsArray, PrintParameters);
#EndIf
	
	If PrintForms.Cancel Then
		CommonUseClientServer.MessageToUser(NStr("en='You have no rights to send print form on printer. Contact your administrator.';ru='Нет прав для вывода печатной формы на принтер, обратитесь к администратору.'"));
		Return;
	EndIf;
	
	// PrintOut
	PrintSpreadsheetDocuments(PrintForms.DocumentsTable, PrintForms.PrintObjects);
	
EndProcedure

// Send tabular documents to printer.
//
// Parameters:
//  DocumentsTable           - ValueList - print forms.
//  PrintObjects                - ValueList - correspondence of objects to the names of tabular document areas.
//  PrintInSets          - Boolean, Undefined - (not used, calculated automatically).
//  KitsCopiesCount    - Number - quantity of copies of each of documents sets.
Procedure PrintSpreadsheetDocuments(DocumentsTable, PrintObjects, Val PrintInSets = Undefined, Val KitsCopiesCount = 1) Export
	
	PrintInSets = DocumentsTable.Count() > 1;
	
	RepresentableDocumentBatch = PrintManagementServerCall.DocumentsPackage(DocumentsTable,
		PrintObjects, PrintInSets, KitsCopiesCount);
		
	RepresentableDocumentBatch.Print(PrintDialogUseMode.DontUse);
EndProcedure

// Executes interactive processing of documents before printing.
// If there are unprocessed documents, it offers to process them. Asks
// user about the continuation if any of the documents are not processed and there are processed ones.
//
// Parameters:
//  EndingProcedureDescription - NotifyDescription - procedure to which the management
//                                                     shall be passed after execution.
//                                Parameters of called procedure:
//                                  DocumentsList - Array - posted documents;
//                                  AdditionalParameters - value that was specified when notification
//                                                            object was created.
//  DocumentsList            - Array            - references to documents required to process.
//  Form                       - ManagedForm  - form from which the command was called. Parameter is
//                                                    required
//                                                    when the procedure is called from object form for form rereading.
Procedure CheckThatDocumentsArePosted(EndingProcedureDescription, DocumentsList, Form = Undefined) Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("EndingProcedureDescription", EndingProcedureDescription);
	AdditionalParameters.Insert("DocumentsList", DocumentsList);
	AdditionalParameters.Insert("Form", Form);
	
	UnpostedDocuments = CommonUseServerCall.CheckThatDocumentsArePosted(DocumentsList);
	ThereAreUnpostedDocuments = UnpostedDocuments.Count() > 0;
	If ThereAreUnpostedDocuments Then
		AdditionalParameters.Insert("UnpostedDocuments", UnpostedDocuments);
		PrintManagementServiceClient.CheckDocumentsPostingPostingDialog(AdditionalParameters);
	Else
		ExecuteNotifyProcessing(EndingProcedureDescription, DocumentsList);
	EndIf;
	
EndProcedure

// Handler of dynamically connected print command.
//
// Command  - FormCommand - connected form command which executes handler Attachable_ExecutePrintCommand.
//            (alternative call*) Structure    - String of table PrintCommands coverted to the structure.
// Source - FormTable, FormDataStructure - source of print objects (Form.Object, Form.Items.List).
//            (alternative call*) Array - list of print objects.
//
// *Alternative call - these types are used if the call is coming
//                         not from standard handler Attachable_ExecutePrintCommand.
//
Procedure ExecuteConnectedPrintCommand(Val Command, Val Form, Val Source) Export
	
	CommandDetails = Command;
	If TypeOf(Command) = Type("FormCommand") Then
		CommandDetails = DetailsPrintCommands(Command.Name, Form.Commands.Find("AddressPrintingCommandsInTemporaryStorage").Action);
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CommandDetails", CommandDetails);
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("Source", Source);
	
	If Not CommandDetails.DoNotPerformRecordInForm AND TypeOf(Source) = Type("FormDataStructure")
		AND (Source.Ref.IsEmpty() Or Form.Modified) Then
		
		If Source.Ref.IsEmpty() Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Data is still not recorded.
		|Execution of action ""%1"" is possible only after data is recorded.
		|Data will be written.';ru='Данные еще не записаны.
		|Выполнение действия ""%1"" возможно только после записи данных.
		|Данные будут записаны.'"),
				CommandDetails.Presentation);
				
			NotifyDescription = New NotifyDescription("ExecuteConnectedPrintCommandRecordConfirmation", PrintManagementServiceClient, AdditionalParameters);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.OKCancel);
			Return;
		EndIf;
		PrintManagementServiceClient.ExecuteConnectedPrintCommandRecordConfirmation(DialogReturnCode.OK, AdditionalParameters);
		Return;
	EndIf;
	
	PrintManagementServiceClient.ExecuteConnectedPrintCommandRecordConfirmation(Undefined, AdditionalParameters);
	
EndProcedure

// Opens form PrintingDocuments for collections of tabular documents.
//
// Parameters:
//  PrintFormsCollection - Array - collection of descriptions of print forms, see NewPrintedFormsCollection;
//  PrintObjects - ValueList  - value - ref to object;
//                                    Presentation - area name in which the object was shown (output parameter);
//  FormOwner - ManagedForm - form from which the printing is executed.
//
Procedure PrintingDocuments(PrintFormsCollection, Val PrintObjects = Undefined, FormOwner = Undefined) Export
	If PrintObjects = Undefined Then
		PrintObjects = New ValueList;
	EndIf;
	
	UniqueKey = String(New UUID);
	
	OpenParameters = New Structure("PrintManagerName,TemplateNames,CommandParameter,PrintParameters");
	OpenParameters.CommandParameter = New Array;
	OpenParameters.PrintParameters = New Structure;
	OpenParameters.Insert("PrintFormsCollection", PrintFormsCollection);
	OpenParameters.Insert("PrintObjects", PrintObjects);
	
	OpenForm("CommonForm.PrintingDocuments", OpenParameters, FormOwner, UniqueKey);
EndProcedure

// Returns prepared list of print forms.
//
// Parameters:
//  IDs - String - identifiers of print forms.
//
// Returns:
//  Array - collection of descriptions of print forms.
Function NewPrintedFormsCollection(IDs) Export
	Return PrintManagementServerCall.NewPrintedFormsCollection(IDs);
EndFunction

// Returns the description of print form found in the collection.
// If the description is not found, returns Undefined.
//
// Parameters:
//  PrintFormsCollection - Array - see PrintManagement.PreparePrintFormsCollection();
//  ID         - String - identifier of print form.
//
// ReturnValue:
//  Structure - found description of print form.
Function PrintFormDescription(PrintFormsCollection, ID) Export
	For Each PrintFormDescription IN PrintFormsCollection Do
		If PrintFormDescription.NameUPPER = Upper(ID) Then
			Return PrintFormDescription;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

#Region WorkWithOfficeDocumentsTemplates

////////////////////////////////////////////////////////////////////////////////
// Work with templates of office documents.

//	Section contains interface functions (API) used
//	when creating print forms based on office documents. At the moment
//	two office packages are supported - MS Office (MS Word templates) and Open Office (OO Writer templates).
//
//	/////////////////////////////////////////////////////////////////////////////
//	Types used data (defined specific implementations).
//	ReferencePrintForm	- reference to print form.
//	RefTemplate			- reference to template.
//	Area				- reference to the area in print form
//						or template (structure) is completed in
//						interface module of service information about the area.
//	DetailsOfArea			- description of template area (see below).
//	FillingData		- either structure, either array structures (for case
//							lists and table//s.
//	///////////////////////////////////////////////////////////////////////////
//	DetailsOfArea - structure describing template areas key
//	AreaName prepared by user - area
//	name key TypeAreaType - 	Header.
//							Footer
//							Common
//							TableRow
//							List
//

////////////////////////////////////////////////////////////////////////////////
// Functions of initialization and references closure.

// Creates connection with output print form.
// Shall be called before any actions with form.
// Function does not work in any other browsers except IE.
// Before executing the function in the web client, you should enable files extension.
// 
// Parameters:
// DocumentType            - String - type of print form "DOC" or "ODT";
// TemplatePageSettings - Map - Parameters of the structure returned by function InitializeTemplate;
// Template                   - Structure - InitializeTemplate function result.
// 
// Returns:
//  Structure.
// 
// Note: parameter TemplatePageSettings is out of date, ignore it and use parameter Template.
//
Function InitializePrintForm(Val DocumentType, Val TemplatePageSettings = Undefined, Template = Undefined) Export
	
	If Upper(DocumentType) = "DOC" Then
		Parameter = ?(Template = Undefined, TemplatePageSettings, Template); // for backward compatibility.
		PrintForm = PrintManagementMSWordClient.InitializePrintFormMSWord(Parameter);
		PrintForm.Insert("Type", "DOC");
		PrintForm.Insert("LastDisplayedArea", Undefined);
		Return PrintForm;
	ElsIf Upper(DocumentType) = "ODT" Then
		PrintForm = PrintManagementOOWriterClient.InitializePrintFormOOWriter(Template);
		PrintForm.Insert("Type", "ODT");
		PrintForm.Insert("LastDisplayedArea", Undefined);
		Return PrintForm;
	EndIf;
	
EndFunction

// Creates COM connection with template. Further on this connection is used when areas (tags and tables)
// are received from it.
// Function does not work in any other browsers except IE.
// Before executing the function in the web client, you should enable files extension.
//
// Parameters:
//  TemplateBinaryData - BinaryData - binary data of template;
//  TemplateType            - String - template type of print form "DOC" or "ODT";
//  TemplateName            - String - name that will be used when you create temporary file of template.
// Returns:
//  Structure.
//
Function InitializeOfficeDocumentTemplate(Val TemplateBinaryData, Val TemplateType, Val TemplateName = "") Export
	
	Template = Undefined;
	TempFileName = "";
	
	#If WebClient Then
		If IsBlankString(TemplateName) Then
			TempFileName = String(New UUID) + "." + Lower(TemplateType);
		Else
			TempFileName = TemplateName + "." + Lower(TemplateType);
		EndIf;
		
		FileDescriptionFulls = New Array;
		FileDescriptionFulls.Add(New TransferableFileDescription(TempFileName, PutToTempStorage(TemplateBinaryData)));
		
		If Not GetFiles(FileDescriptionFulls, , TempFilesDir(), False) Then
			Return Undefined;
		EndIf;
		
		TempFileName = CommonUseClientServer.AddFinalPathSeparator(TempFilesDir()) + TempFileName;
	#EndIf
	
	If Upper(TemplateType) = "DOC" Then
		Template = PrintManagementMSWordClient.GetMSWordTemplate(TemplateBinaryData, TempFileName);
		Template.Insert("Type", "DOC");
	ElsIf Upper(TemplateType) = "ODT" Then
		Template = PrintManagementOOWriterClient.GetOOWriterTemplate(TemplateBinaryData, TempFileName);
		Template.Insert("Type", "ODT");
		Template.Insert("TemplatePageSettings", Undefined);
	EndIf;
	
	Return Template;
	
EndFunction

// Releases the references in created communication interface with office application.
// It is required to call each time after completing
// template generation and outputting a print form to the user.
// Parameters:
// Handler - ReferencePrintForm,
// ReferenceTemplate CloseApplication - Boolean - flag showing if it is required to close the application.
// 				Connection with template shall be created with application closing.
// 				not necessary to close PrintForm.
//
Procedure ClearReferences(Handler, Val CloseApplication = True) Export
	
	If Handler <> Undefined Then
		If Handler.Type = "DOC" Then
			PrintManagementMSWordClient.CloseConnection(Handler, CloseApplication);
		Else
			PrintManagementOOWriterClient.CloseConnection(Handler, CloseApplication);
		EndIf;
		Handler = Undefined;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Function for displaying print forms to the user.

// Shows generated document to user.
// Actually sets the flag of visible to it.
// Parameters:
//  Handler - ReferencePrintForm
//
Procedure ShowDocument(Val Handler) Export
	
	If Handler.Type = "DOC" Then
		PrintManagementMSWordClient.ShowMSWordDocument(Handler);
	ElsIf Handler.Type = "ODT" Then
		PrintManagementOOWriterClient.ShowOOWriterDocument(Handler);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for receiving areas from the template, outputting template areas
// to print form and filling in parameters in them.

// Receives area from print form template.
//
// Parameters:
//   RefsOnTemplate   - Structure - reference to print form template.
//   DetailsOfArea - Structure - area description.
//
// Return
//   value Structure - area from template.
//
Function TemplateArea(Val RefsOnTemplate, Val DetailsOfArea) Export
	
	Area = Undefined;
	If RefsOnTemplate.Type = "DOC" Then
		
		If		DetailsOfArea.AreaType = "Header" Then
			Area = PrintManagementMSWordClient.GetTopFooterArea(RefsOnTemplate);
		ElsIf	DetailsOfArea.AreaType = "Footer" Then
			Area = PrintManagementMSWordClient.GetLowerFooterArea(RefsOnTemplate);
		ElsIf	DetailsOfArea.AreaType = "Common" Then
			Area = PrintManagementMSWordClient.GetMSWordTemplateArea(RefsOnTemplate, DetailsOfArea.AreaName, 1, 0);
		ElsIf	DetailsOfArea.AreaType = "TableRow" Then
			Area = PrintManagementMSWordClient.GetMSWordTemplateArea(RefsOnTemplate, DetailsOfArea.AreaName);
		ElsIf	DetailsOfArea.AreaType = "List" Then
			Area = PrintManagementMSWordClient.GetMSWordTemplateArea(RefsOnTemplate, DetailsOfArea.AreaName, 1, 0);
		Else
			Raise
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Area type is not specified or specified incorrectly: %1.';ru='Тип области не указан или указан не корректно: %1.'"), DetailsOfArea.AreaType);
		EndIf;
		
		If Area <> Undefined Then
			Area.Insert("DetailsOfArea", DetailsOfArea);
		EndIf;
	ElsIf RefsOnTemplate.Type = "ODT" Then
		
		If		DetailsOfArea.AreaType = "Header" Then
			Area = PrintManagementOOWriterClient.GetTopFooterArea(RefsOnTemplate);
		ElsIf	DetailsOfArea.AreaType = "Footer" Then
			Area = PrintManagementOOWriterClient.GetLowerFooterArea(RefsOnTemplate);
		ElsIf	DetailsOfArea.AreaType = "Common"
				OR DetailsOfArea.AreaType = "TableRow"
				OR DetailsOfArea.AreaType = "List" Then
			Area = PrintManagementOOWriterClient.GetTemplateArea(RefsOnTemplate, DetailsOfArea.AreaName);
		Else
			Raise
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Area type is not specified or specified incorrectly: %1.';ru='Тип области не указан или указан не корректно: %1.'"), DetailsOfArea.AreaName);
		EndIf;
		
		If Area <> Undefined Then
			Area.Insert("DetailsOfArea", DetailsOfArea);
		EndIf;
	EndIf;
	
	Return Area;
	
EndFunction

// Attaches area to print form from template.
// Applied at single area output.
//
// Parameters:
// PrintForm - ReferencePrintForm - reference to print form.
// TemplateArea - Area - area from template.
// TransitionToNextString - Boolean, whether it is required to insert break after area output.
//
Procedure JoinArea(Val PrintForm,
							  Val TemplateArea,
							  Val TransitionToNextString = True) Export
							  
	If TemplateArea = Undefined Then
		Return;						  
	EndIf; 
								  
	Try
		DetailsOfArea = TemplateArea.DetailsOfArea;
		
		If PrintForm.Type = "DOC" Then
			
			DevelopedArea = Undefined;
			
			If		DetailsOfArea.AreaType = "Header" Then
				PrintManagementMSWordClient.AddHeader(PrintForm, TemplateArea);
			ElsIf	DetailsOfArea.AreaType = "Footer" Then
				PrintManagementMSWordClient.AddFooter(PrintForm, TemplateArea);
			ElsIf	DetailsOfArea.AreaType = "Common" Then
				DevelopedArea = PrintManagementMSWordClient.JoinArea(PrintForm, TemplateArea, TransitionToNextString);
			ElsIf	DetailsOfArea.AreaType = "List" Then
				DevelopedArea = PrintManagementMSWordClient.JoinArea(PrintForm, TemplateArea, TransitionToNextString);
			ElsIf	DetailsOfArea.AreaType = "TableRow" Then
				If PrintForm.LastDisplayedArea <> Undefined
				   AND PrintForm.LastDisplayedArea.AreaType = "TableRow"
				   AND Not PrintForm.LastDisplayedArea.TransitionToNextString Then
					DevelopedArea = PrintManagementMSWordClient.JoinArea(PrintForm, TemplateArea, TransitionToNextString, True);
				Else
					DevelopedArea = PrintManagementMSWordClient.JoinArea(PrintForm, TemplateArea, TransitionToNextString);
				EndIf;
			Else
				Raise(NStr("en='Area type is not specified or specified incorrectly.';ru='Тип области не указан или указан не корректно.'"));
			EndIf;
			
			DetailsOfArea.Insert("Area", DevelopedArea);
			DetailsOfArea.Insert("TransitionToNextString", TransitionToNextString);
			
			// Contains area type and boundaries (if required).
			PrintForm.LastDisplayedArea = DetailsOfArea;
			
		ElsIf PrintForm.Type = "ODT" Then
			If		DetailsOfArea.AreaType = "Header" Then
				PrintManagementOOWriterClient.AddHeader(PrintForm, TemplateArea);
			ElsIf	DetailsOfArea.AreaType = "Footer" Then
				PrintManagementOOWriterClient.AddFooter(PrintForm, TemplateArea);
			ElsIf	DetailsOfArea.AreaType = "Common"
					OR DetailsOfArea.AreaType = "List" Then
				PrintManagementOOWriterClient.SetMainCursorOnDocumentBody(PrintForm);
				PrintManagementOOWriterClient.JoinArea(PrintForm, TemplateArea, TransitionToNextString);
			ElsIf	DetailsOfArea.AreaType = "TableRow" Then
				PrintManagementOOWriterClient.SetMainCursorOnDocumentBody(PrintForm);
				PrintManagementOOWriterClient.JoinArea(PrintForm, TemplateArea, TransitionToNextString, True);
			Else
				Raise(NStr("en='Area type is not specified or specified incorrectly.';ru='Тип области не указан или указан не корректно.'"));
			EndIf;
			// Contains area type and boundaries (if required).
			PrintForm.LastDisplayedArea = DetailsOfArea;
		EndIf;
	Except
		ErrorInfo = TrimAll(BriefErrorDescription(ErrorInfo()));
		ErrorInfo = ?(Right(ErrorInfo, 1) = ".", ErrorInfo, ErrorInfo + ".");
		ErrorInfo = ErrorInfo + " " +
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='An error occurred when attempting to get area ""%1"" from the template.';ru='Ошибка при попытке вывести область ""%1"" из макета.'"),
					TemplateArea.DetailsOfArea.AreaName);
		Raise ErrorInfo;
	EndTry;
	
EndProcedure

// Fills in the parameters of print form area.
//
// Parameters:
// PrintForm	- ReferencePrintForm, Area - print form area or print form itself.
// Data			- FillingData
//
Procedure FillParameters(Val PrintForm, Val Data) Export
	
	DetailsOfArea = PrintForm.LastDisplayedArea;
	
	If PrintForm.Type = "DOC" Then
		If		DetailsOfArea.AreaType = "Header" Then
			PrintManagementMSWordClient.FillHeaderParameters(PrintForm, Data);
		ElsIf	DetailsOfArea.AreaType = "Footer" Then
			PrintManagementMSWordClient.FillFooterParameters(PrintForm, Data);
		ElsIf	DetailsOfArea.AreaType = "Common"
				OR DetailsOfArea.AreaType = "TableRow"
				OR DetailsOfArea.AreaType = "List" Then
			PrintManagementMSWordClient.FillParameters(PrintForm.LastDisplayedArea.Area, Data);
		Else
			Raise(NStr("en='Area type is not specified or specified incorrectly.';ru='Тип области не указан или указан не корректно.'"));
		EndIf;
	ElsIf PrintForm.Type = "ODT" Then
		If		PrintForm.LastDisplayedArea.AreaType = "Header" Then
			PrintManagementOOWriterClient.SetMainCursorOnHeader(PrintForm);
		ElsIf	PrintForm.LastDisplayedArea.AreaType = "Footer" Then
			PrintManagementOOWriterClient.SetMainCursorOnFooter(PrintForm);
		ElsIf	DetailsOfArea.AreaType = "Common"
				OR DetailsOfArea.AreaType = "TableRow"
				OR DetailsOfArea.AreaType = "List" Then
			PrintManagementOOWriterClient.SetMainCursorOnDocumentBody(PrintForm);
		EndIf;
		PrintManagementOOWriterClient.FillParameters(PrintForm, Data);
	EndIf;
	
EndProcedure

// Adds the area to print form from the template
// while replacing the parameters in the area with values from object data.
// Applied at single area output.
//
// Parameters:
// PrintForm	- ReferencePrintForm
// TemplateArea	- Data
// Area			- ObjectData
// TransitionToNextString - Boolean, whether it is required to insert break after area output.
//
Procedure JoinAreaAndFillParameters(Val PrintForm,
										Val TemplateArea,
										Val Data,
										Val TransitionToNextString = True) Export
																			
	If TemplateArea <> Undefined Then
		JoinArea(PrintForm, TemplateArea, TransitionToNextString);
		FillParameters(PrintForm, Data)
	EndIf;
	
EndProcedure

// Adds the area to print form from the template
// while replacing the parameters in the area with values from object data.
// Applied at single area output.
//
// Parameters:
// PrintForm	- ReferencePrintForm
// TemplateArea	- Area - template area.
// Data			- ObjectData (array of structures).
// TransitionToNextString - Boolean, whether it is required to insert break after area output.
//
Procedure JoinAndFillCollection(Val PrintForm,
										Val TemplateArea,
										Val Data,
										Val TransitionToNextString = True) Export
	If TemplateArea = Undefined Then
		Return;
	EndIf;
	
	DetailsOfArea = TemplateArea.DetailsOfArea;
	
	If PrintForm.Type = "DOC" Then
		If		DetailsOfArea.AreaType = "TableRow" Then
			PrintManagementMSWordClient.JoinAndFillTableArea(PrintForm, TemplateArea, Data, TransitionToNextString);
		ElsIf	DetailsOfArea.AreaType = "List" Then
			PrintManagementMSWordClient.JoinAndFillSet(PrintForm, TemplateArea, Data, TransitionToNextString);
		Else
			Raise(NStr("en='Area type is not specified or specified incorrectly.';ru='Тип области не указан или указан не корректно.'"));
		EndIf;
	ElsIf PrintForm.Type = "ODT" Then
		If		DetailsOfArea.AreaType = "TableRow" Then
			PrintManagementOOWriterClient.JoinAndFillCollection(PrintForm, TemplateArea, Data, True, TransitionToNextString);
		ElsIf	DetailsOfArea.AreaType = "List" Then
			PrintManagementOOWriterClient.JoinAndFillCollection(PrintForm, TemplateArea, Data, False, TransitionToNextString);
		Else
			Raise(NStr("en='Area type is not specified or specified incorrectly.';ru='Тип области не указан или указан не корректно.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Inserts a break between rows as a new line character.
// Parameters:
// PrintForm - ReferencePrintForm
//
Procedure InsertBreakAtNewLine(Val PrintForm) Export
	
	If	  PrintForm.Type = "DOC" Then
		PrintManagementMSWordClient.InsertBreakAtNewLine(PrintForm);
	ElsIf PrintForm.Type = "ODT" Then
		PrintManagementOOWriterClient.InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// Outdated. You shall use TemplateArea.
//
Function GetArea(Val RefTemplate, Val DetailsOfArea) Export
	
	Return TemplateArea(RefTemplate, DetailsOfArea);
	
EndFunction

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// Before executing print command check if at least one object is transferred
// as for commands with multiple use mode an empty array can be transferred.
Function CheckQuantityOfPassedObjects(CommandParameter)
	
	If TypeOf(CommandParameter) = Type("Array") AND CommandParameter.Count() = 0 Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Returns the command description according to the name of the form.
// 
// See PrintManagement.PrintCommandDetails
//
Function DetailsPrintCommands(CommandName, AddressPrintingCommandsInTemporaryStorage)
	
	Return PrintManagementClientReUse.DetailsPrintCommands(CommandName, AddressPrintingCommandsInTemporaryStorage);
	
EndFunction

// Opens import dialog form of template file for editing in the external application.
Procedure EditTemplateInExternalApplication(NOTifyDescription, TemplateParameters, Form) Export
	OpenForm("InformationRegister.UserPrintTemplates.Form.TemplateEditing", TemplateParameters, Form, , , , NotifyDescription);
EndProcedure

#Region UseModality

// UseModality

#If WebClient Then
// Outdated. Used by outdated function InitializeTemplate.
//
// Function receives file(s) from server to local directory on disk
// and returns the name of directory in
// which they were saved Parameters:
// PathToDirectory - String - path to the directory in which files
// FilesToReceive shall be saved - Map - 
//                         Key  - value
//                         attachment file name - binary data of file
//
Function GetFilesToFilesPrintDirectory(PathToDirectory, FilesToReceive) Export
	
	NeedToSetPrintDirectory = Not ValueIsFilled(PathToDirectory);
	If Not NeedToSetPrintDirectory Then
		File = New File(PathToDirectory);
		If Not File.Exist() Then
			NeedToSetPrintDirectory = True;
		EndIf;
	EndIf;
	
	If NeedToSetPrintDirectory Then
		PathToDirectory = TempFilesDir();
	EndIf;
	
	FilesInTemporaryStorage = GetFileAddressesInTemporaryStorage(FilesToReceive);
	
	FileDescriptionFulls = New Array;
	
	For Each FileInTemporaryStorage IN FilesInTemporaryStorage Do
		FileDescriptionFulls.Add(New TransferableFileDescription(FileInTemporaryStorage.Key,FileInTemporaryStorage.Value));
	EndDo;
	
	If Not GetFiles(FileDescriptionFulls, , PathToDirectory, False) Then
		Return Undefined;
	EndIf;
	
	If Right(PathToDirectory, 1) <> "\" Then
		PathToDirectory = PathToDirectory + "\";
	EndIf;
	
	Return PathToDirectory;
	
EndFunction

// Outdated. Used by outdated function GetFilesToFilesPrintDirectory.
// Puts sets of binary data to
// temporary storage Parameters:
// 	SetValues - map, key - key associated with
// 								  binary data value - BinaryData
// Return value:
// map: key - key associated with an address
//               in a temporary storage value - address in temporary storage
//
Function GetFileAddressesInTemporaryStorage(SetValues)
	
	Result = New Map;
	
	For Each KeyValue IN SetValues Do
		Result.Insert(KeyValue.Key, PutToTempStorage(KeyValue.Value));
	EndDo;
	
	Return Result;
	
EndFunction
#EndIf

// Outdated. You shall use CheckThatDocumentsAreProcessed.
//
// Executes interactive processing of documents before printing.
// If there are unprocessed documents, it offers to process them. Asks
// user about the continuation if any of the documents are not processed and there are processed ones.
//
// DocumentsArray
//  parameters - Array           - references to documents required to process before printing.
//                                       After execution of the function from the array unprocessed documents are excluded.
//  FormSource   - ManagedForm - form from which the command was called.
//
// Returns:
//  Boolean - there are documents for printing in parameter DocumentsArray.
//
Function CheckDocumentsPosted(DocumentsArray, FormSource = Undefined) Export
	
	ClearMessages();
	DocumentsRequiredPosting = CommonUseServerCall.CheckThatDocumentsArePosted(DocumentsArray);
	UnpostedDocumentsCount = DocumentsRequiredPosting.Count();
	
	If UnpostedDocumentsCount > 0 Then
		
		If UnpostedDocumentsCount = 1 Then
			QuestionText = NStr("en='To print the document, post it first. Post the document and continue?';ru='Для того чтобы распечатать документ, его необходимо предварительно провести. Выполнить проведение документа и продолжить?'");
		Else
			QuestionText = NStr("en='To print documents, it is required to post them first. Post the documents and continue?';ru='Для того чтобы распечатать документы, их необходимо предварительно провести. Выполнить проведение документов и продолжить?'");
		EndIf;
		
		ResponseCode = DoQueryBox(QuestionText, QuestionDialogMode.YesNo);
		If ResponseCode <> DialogReturnCode.Yes Then
			Return False;
		EndIf;
		
		DataAboutUnpostedDocuments = CommonUseServerCall.PostDocuments(DocumentsRequiredPosting);
		
		// inform about the documents that were not processed
		MessagePattern = NStr("en='Document %1 is not posted: %2 Cannot print.';ru='Документ %1 не проведен: %2 Печать невозможна.'");
		UnpostedDocuments = New Array;
		For Each InformationAboutDocument IN DataAboutUnpostedDocuments Do
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(InformationAboutDocument.Ref), 
					InformationAboutDocument.ErrorDescription), InformationAboutDocument.Ref);
			UnpostedDocuments.Add(InformationAboutDocument.Ref);		
		EndDo;
		
		UnpostedDocumentsCount = UnpostedDocuments.Count();
		
		// alert open forms that the documents were processed
		PostedDocuments = CommonUseClientServer.ReduceArray(DocumentsRequiredPosting, UnpostedDocuments);
		PostedDocumentsTypes = New Map;
		For Each PostedDocument IN PostedDocuments Do
			PostedDocumentsTypes.Insert(TypeOf(PostedDocument));
		EndDo;
		For Each Type IN PostedDocumentsTypes Do
			NotifyChanged(Type.Key);
		EndDo;
		
		// If command is called from form, then read an actual (posted) copy from base to form.
		If TypeOf(FormSource) = Type("ManagedForm") Then
			Try
				FormSource.Read();	
			Except
				// If there is no Read method, the printing is executed not from the object form.
			EndTry;
		EndIf;
		
		// update initial array of documents
		DocumentsArray = CommonUseClientServer.ReduceArray(DocumentsArray, UnpostedDocuments);

	EndIf;
	
	AreDocumentsWhichCanPrint = DocumentsArray.Count() > 0;
	
	Cancel = False;
	If UnpostedDocumentsCount > 0 Then
		// ask a user if it is necessary to continue printing when there are unprocessed documents.
		
		DialogText = NStr("en='Cannot post one or several documents.';ru='Не удалось провести один или несколько документов.'");
		DialogButtons = New ValueList;
		
		If AreDocumentsWhichCanPrint Then
			DialogText = DialogText + " " + NStr("en='Continue?';ru='Продолжить?'");
			DialogButtons.Add(DialogReturnCode.Ignore, NStr("en='Continue';ru='Продолжить'"));
			DialogButtons.Add(DialogReturnCode.Cancel);
		Else
			DialogButtons.Add(DialogReturnCode.OK);
		EndIf;
		
		Response = DoQueryBox(DialogText, DialogButtons);
		If Response <> DialogReturnCode.Ignore Then
			Cancel = True;
		EndIf;
	EndIf;
	
	Return Not Cancel;
	
EndFunction

// Outdated. You shall use procedure InitializeOfficeDocumentTemplate.
//
// Creates the connection with template. Further on this connection
// is used when areas (tags and tables) are received from it.
//
// Parameters:
//  TemplateBinaryData - BinaryData - binary data
//  of template TemplateType            - String - template type of print form "DOC" or "ODT";
// Returns:
//  Structure.
//
Function InitializeTemplate(Val TemplateBinaryData, Val TemplateType, Val PathToDirectory = "", Val TemplateName = "") Export
	
#If WebClient Then
	MessageText = NStr("en='To continue printing, install the file operation extension.';ru='Для продолжения печати необходимо установить расширение работы с файлами.'");
	If Not CommonUseClient.FileOperationsExtensionConnected(MessageText) Then
		Return Undefined;
	EndIf;
	
	If IsBlankString(TemplateName) Then
		TempFileName = String(New UUID) + "." + Lower(TemplateType);
	Else
		TempFileName = TemplateName + "." + Lower(TemplateType);
	EndIf;
	
	FilesToReceive = New Map;
	FilesToReceive.Insert(TempFileName, TemplateBinaryData);
	
	Result = GetFilesToFilesPrintDirectory(PathToDirectory, FilesToReceive);
	
	If Result = Undefined Then
		Return Undefined;
	EndIf;
	
	TempFileName = Result + TempFileName;
#Else
	TempFileName = "";
#EndIf

	If Upper(TemplateType) = "DOC" Then
		Template = PrintManagementMSWordClient.GetMSWordTemplate(TemplateBinaryData, TempFileName);
		Template.Insert("Type", "DOC");
		Return Template;
	ElsIf Upper(TemplateType) = "ODT" Then
		Template = PrintManagementOOWriterClient.GetOOWriterTemplate(TemplateBinaryData, TempFileName);
		Template.Insert("Type", "ODT");
		Template.Insert("TemplatePageSettings", Undefined);
		Return Template;
	EndIf;
	
EndFunction

// End ModalityUse

#EndRegion

#EndRegion
