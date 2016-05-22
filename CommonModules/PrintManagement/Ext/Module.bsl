////////////////////////////////////////////////////////////////////////////////
// Subsystem "Print".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the description of print form found in the collection.
// If the description is not found, returns Undefined.
//
// Parameters:
//  PrintFormsCollection - ValueTable - see PrepareCollectionOfPrintForms();
//  TemplateName             - String          - name of the layout being checked.
//
// ReturnValue:
//  ValueTableRow - found description of print form.
Function InformationAboutPrintForm(PrintFormsCollection, ID) Export
	Return PrintFormsCollection.Find(Upper(ID), "NameUPPER");
EndFunction

// Check whether it is required to print a layout.
//
// Parameters:
//  PrintFormsCollection - ValueTable - see PrepareCollectionOfPrintForms();
//  TemplateName             - String          - name of the layout being checked.
//
// Returns:
//  Boolean - True if the layout is to be printed.
Function NeedToPrintTemplate(PrintFormsCollection, TemplateName) Export
	
	Return PrintFormsCollection.Find(Upper(TemplateName), "NameUPPER") <> Undefined;
	
EndFunction

// Adds a tabular document to the print form collection.
//
// Parameters:
//  PrintFormsCollection - ValueTable - see PrepareCollectionOfPrintForms();
//  TemplateName             - String - layout name;
//  TemplateSynonym         - String - layout presentation;
//  SpreadsheetDocument     - SpreadsheetDocument - print form of the document;
//  Picture              - Picture;
//  FullPathToTemplate     - String - path to the layout in the metadata tree, for example:
//                                   "Document.InvoiceForPayment.PF_MXL_OrderInvoice".
//                                   If you do not specify the parameter, users will
//                                   not be able to edit the layout in the PrintDocuments form.
//  FileNamePrintedForm - String - name used to save a print form as a file;
//                        - Map:
//                           * Key     - AnyRef - ref to print object;
//                           * Value - String - attachment file name.
Procedure OutputSpreadsheetDocumentToCollection(PrintFormsCollection, TemplateName, TemplateSynonym, SpreadsheetDocument,
	Picture = Undefined, FullPathToTemplate = "", FileNamePrintedForm = Undefined) Export
	
	PrintFormDescription = PrintFormsCollection.Find(Upper(TemplateName), "NameUPPER");
	If PrintFormDescription <> Undefined Then
		PrintFormDescription.SpreadsheetDocument = SpreadsheetDocument;
		PrintFormDescription.TemplateSynonym = TemplateSynonym;
		PrintFormDescription.Picture = Picture;
		PrintFormDescription.FullPathToTemplate = FullPathToTemplate;
		PrintFormDescription.FileNamePrintedForm = FileNamePrintedForm;
	EndIf;
	
EndProcedure

// Defines an object print area in the tabular document.
// It is used to link a tabular document area to the print object (a ref).
// Call it when a print form area in the
// tabular document is being generated.
//
// Parameters:
//  SpreadsheetDocument - SpreadsheetDocument - print form;
//  FirstLineNumber - Number - position of the next area in the document;
//  PrintObjects - ValueList - list of print objects.;
//  Ref - AnyRef - print object.
Procedure SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Ref) Export
	
	Item = PrintObjects.FindByValue(Ref);
	If Item = Undefined Then
		AreaName = "Document_" + Format(PrintObjects.Count() + 1, "NZ=; NG=");
		PrintObjects.Add(Ref, AreaName);
	Else
		AreaName = Item.Presentation;
	EndIf;
	
	LineNumberEnd = SpreadsheetDocument.TableHeight;
	SpreadsheetDocument.Area(FirstLineNumber, , LineNumberEnd, ).Name = AreaName;

EndProcedure

// Returns a list of external print forms.
//
// Parameters:
//  FullMetadataObjectName - String - Full metadata object name for which it
//                                        is required to get a list of print forms.
//
// Returns:
//  List:
//   * Value      - String - print form identifier;
//   * Presentation - String - presentation of a print form.
Function PrintFormsListFromExternalSources(FullMetadataObjectName) Export
	
	ExternalPrintForms = New ValueList;
	If Not IsBlankString(FullMetadataObjectName) Then
		OnReceivingExternalPrintFormsList(ExternalPrintForms, FullMetadataObjectName);
	EndIf;
	
	Return ExternalPrintForms;
	
EndFunction

// Locates print commands on the form.
//
// Parameters:
//   Form                            - ManagedForm - form on which it is required to locate the Print submenu.
//   PlacePropertiesCommandsDefault - FormItem - group to which it is
//                                                     required to locate the Print submenu, by default, it is located in the form command pane.
//   PrintObjects                    - Array - a list of metadata objects for
//                                               which it is required to create a common submenu Print.
Procedure OnCreateAtServer(Form, PlacePropertiesCommandsDefault = Undefined, PrintObjects = Undefined) Export
	
	If TypeOf(Form) = Type("ManagedForm") Then
		FormName = Form.FormName;
	Else
		FormName = Form;
	EndIf;
	
	If PrintObjects = Undefined Then
		PrintCommands = PrintManagementReUse.PrintCommandsForms(FormName, PrintObjects).Copy();
	Else
		PrintCommands = PrintCommandsForms(FormName, PrintObjects).Copy();
	EndIf;
	
	If PlacePropertiesCommandsDefault <> Undefined Then
		For Each PrintCommand IN PrintCommands Do
			If IsBlankString(PrintCommand.PlaceProperties) Then
				PrintCommand.PlaceProperties = PlacePropertiesCommandsDefault.Name;
			EndIf;
		EndDo;
	EndIf;
	
	PrintCommands.Columns.Add("CommandNameOnForm", New TypeDescription("String"));
	
	CommandTable = PrintCommands.Copy(,"PlaceProperties");
	CommandTable.GroupBy("PlaceProperties");
	AllocationPlace = CommandTable.UnloadColumn("PlaceProperties");
	
	For Each PlaceProperties IN AllocationPlace Do
		FoundsCommands = PrintCommands.FindRows(New Structure("PlaceProperties,HiddenByFunctionalOptions", PlaceProperties, False));
		
		FormItemForPlacement = Form.Items.Find(PlaceProperties);
		If FormItemForPlacement = Undefined Then
			FormItemForPlacement = PlacePropertiesCommandsDefault;
		EndIf;
		
		If FoundsCommands.Count() > 0 Then
			AddPrintCommands(Form, FoundsCommands, FormItemForPlacement);
		EndIf;
	EndDo;
	
	AddressPrintingCommandsInTemporaryStorage = "AddressPrintingCommandsInTemporaryStorage";
	FormCommand = Form.Commands.Find(AddressPrintingCommandsInTemporaryStorage);
	If FormCommand = Undefined Then
		FormCommand = Form.Commands.Add(AddressPrintingCommandsInTemporaryStorage);
		FormCommand.Action = PutToTempStorage(PrintCommands, Form.UUID);
	Else
		CommonCommandsListPrintingForms = GetFromTempStorage(FormCommand.Action);
		For Each PrintCommand IN PrintCommands Do
			FillPropertyValues(CommonCommandsListPrintingForms.Add(), PrintCommand);
		EndDo;
		FormCommand.Action = PutToTempStorage(CommonCommandsListPrintingForms, Form.UUID);
	EndIf;
	
EndProcedure

// Returns a list of print commands for the specified form.
//
// Parameters:
//  Form - ManagedForm, String - a form or a full form name for which it is required to get a list of print commands.
//
// Returns:
//  ValueTable - for the description, see CreateCollectionPrintCommands().
Function PrintCommandsForms(Form, ObjectList = Undefined) Export
	
	If TypeOf(Form) = Type("ManagedForm") Then
		FormName = Form.FormName;
	Else
		FormName = Form;
	EndIf;
	
	PrintCommands = CreateCollectionPrintCommands();
	PrintCommands.Columns.Add("HiddenByFunctionalOptions", New TypeDescription("Boolean"));
	
	StandardProcessing = True;
	PrintManagementOverridable.BeforeAddingPrintCommands(FormName, PrintCommands, StandardProcessing);
	
	If StandardProcessing Then
		MetadataObject = Metadata.FindByFullName(FormName);
		If MetadataObject <> Undefined Then
			MetadataObject = MetadataObject.Parent();
		EndIf;
		
		If ObjectList <> Undefined Then
			FillPrintCommandsForListOfObjects(ObjectList, PrintCommands);
		ElsIf MetadataObject = Undefined Then
			Return PrintCommands;
		Else
			PrintManager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
			CommandsAdded = AddCommandsFromPrintManager(PrintManager, PrintCommands);
			If CommandsAdded Then
				For Each PrintCommand IN PrintCommands Do
					If IsBlankString(PrintCommand.PrintManager) Then
						PrintCommand.PrintManager = MetadataObject.FullName();
					EndIf;
				EndDo;
				If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
					ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
					ModuleAdditionalReportsAndDataProcessors.OnPrintCommandsReceive(PrintCommands, FormName);
				EndIf;
			ElsIf CommonUse.IsDocumentJournal(MetadataObject) Then
				FillPrintCommandsForListOfObjects(MetadataObject.RegisteredDocuments, PrintCommands);
			EndIf;
		EndIf;
	EndIf;
	
	For Each PrintCommand IN PrintCommands Do
		If PrintCommand.Order = 0 Then
			PrintCommand.Order = 99;
		EndIf;
		PrintCommand.AdditionalParameters.Insert("ComplementKitWithExternalPrintForms", PrintCommand.ComplementKitWithExternalPrintForms);
	EndDo;
	
	PrintCommands.Sort("Order Asc, Presentation Asc");
	
	NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FormName, ".", True);
	ShortNameForms = NameParts[NameParts.Count()-1];
	
	// filter by form names
	For LineNumber = -PrintCommands.Count() + 1 To 0 Do
		PrintCommand = PrintCommands[-LineNumber];
		FormsList = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(PrintCommand.FormsList, ",", True);
		If FormsList.Count() > 0 AND FormsList.Find(ShortNameForms) = Undefined Then
			PrintCommands.Delete(PrintCommand);
		EndIf;
	EndDo;
	
	DetermineVisiblePrintCommandsForFunctionalOptions(PrintCommands, Form);
	
	Return PrintCommands;
	
EndFunction

// Creates an empty table to place print commands to it.
// 
// Returns:
//  ValueTable - Print commands description:
//
//  * Identifier - String - Print command identifier using which a
//                             print manager defines a print form to be generated.
//                             Example: "OrderInvoice".
//
//                                        To print multiple print forms, you can specify their
//                                        several identifiers (as a line, separated by commas, or an array of lines, for example:
//                                         "OrderInvoice,WarrantyLetter".
//
//                                        If you want to specify a number of print form
//                                        copies to be printed, type its identifier several
//                                        times depending on how many copies you need. Note that print forms sequence in
//                                        the package is the same as a sequence of
//                                        print forms identifiers specified in the parameter. Example (2 invoices for payment + 1 warranty letter):
//                                        "OrderInvoice,OrderInvoice,WarrantyLetter".
//
//                                        Print form identifier may also contain an alternative
//                                        print manager if it differs from the one specified
//                                        in parameter PrintManager, for example, "OrderInvoice, DataProcessor.PrintingForm.WarrantyLetter".
//
//                                        IN this example, WarrantyLetter is generated in the print manager.
//                                        Processing.PrintForm and OrderInvoice - in the print manager
//                                        specified in parameter PrintManager.
//
//                  - Array - identifier list of print commands.
//
//  * Presentation - String            - Command presentation in the Print menu. 
//                                         Example: "Invoice for payment".
//
//  * PrintManager - String           - (optional) Object name in which
//                                        manager module the Print procedure is located. The procedure generates tabular documents for the command.
//                                        Default value: name of the object manager module.
//                                         Example: "Document.InvoiceForPayment".
//  * PrintingObjectsTypes - Array       - (optional) a list of object types
//                                        to which the print command applies. The parameter is used for print commands in
//                                        document logs where it is required to check a passed object type before calling the print manager.
//                                        If the list is not filled in, then while automatically
//                                        creating a list of print commands in the document journal,
//                                        it is filled in with the object type from which the print command was imported.
//
//  * Handler    - String            - (optional) Client command handler to which
//                                        it is required to pass the management instead of the standard handler of the print command. It
//                                        is used, for example, when a print form is generated on client.
//                                         Example: "PrintHandlersClient.PrintBuyerInvoicesForPayment".
//
//  * Order       - Number             - (optional) Value from 1 to 100
//                                        that specifies command location order relatively to other commands. Commands of menu
//                                        Print are first sorted by field Order, then by presentation.
//                                        Default value: 99.
//
//  * Picture      - Picture          - (optional) Picture that is displayed near the command in the Print menu.
//                                         Example: PicturesLib.FormatPDF.
//
//  * FormsList    - String            - (optional) Form names separated by commas
//                                        in which a command should be displayed. If the parameter is not specified, then print command
//                                        will appear in all forms of the object with the Print subsystem.
//                                         Example: "DocumentForm".
//
//  * Location - String          - (optional) Form command panel name to
//                                        which it is required to put the print command. The parameter shall be used only when
//                                        the form has more than one submenu "Print". IN the rest
//                                        of cases the location shall be specified in the form module when calling the method.
//                                        PrintManagement.OnCreateAtServer.
//                                        
//  * FormTitle  - String          - (optional) Custom string that
//                                        predefines standard form title "Print documents".
//                                         Example: "Custom kit".
//
//  * FunctionalOptions - String      - (optional) Functional option names separated by
//                                        commas that affect the print commands availability.
//
//  * CheckPostingBeforePrint - Boolean - (optional) Shows that
//                                        it is required to check whether documents are posted before printing. If the parameter is not specified,
//                                        then posting check is not executed.
//
//  * StraightToPrinter - Boolean           - (optional) Shows that it is
//                                        required to print documents without a preview, pass it right to the printer. If the parameter is not specified,
//                                        then when you select a print command, preview form "Print documents" is opened.
//
//  * SavingFormat - SpreadsheetDocumentFileType - (optional) It is applied for
//                                        a quick saving of a print form (without additional actions) to different formats different from mxl.
//                                        If the parameter is not specified, a normal mxl is generated.
//                                         Example: SpreadsheetDocumentFileType.PDF.
//
//                                        When you select print commands, the document generated in
//                                        pdf format is opened immediately.
//
//  * OverrideUserCountSettings - Boolean - (optional) Shows that
//                                        it is required to disable
//                                        the mechanism of saving/restoring the number of copies to print selected by user in form PrintingDocuments. If the parameter is
//                                        not specified, then the saving/restoring mechanism will work on the form opening.
//                                        PrintingDocuments.
//
//  * ComplementKitWithExternalPrintForms - Boolean - (optional) Shows that
//                                        it is required to expand the documents set
//                                        with all external print forms connected to an object (the AdditionalReportsAndDataProcessors subsystem). If the parameter is
//                                        not specified, the external print forms are not added to the kit.
//
//  * FixedKit - Boolean    - (optional) Shows that it is
//                                        required to lock changing the documents set content by a user. If the parameter is not specified,
//                                        then the user can exclude separate print forms from the
//                                        kit in form PrintingDocuments and also modify their quantity.
//
//  * AdditionalParameters - Structure - (optional) - random parameters for sending to printing manager.
//
//  * DoNotPerformRecordInForm - Boolean  - (optional) Shows that it is
//                                        required to disable the mechanism of object writing before running the print command. Used in exceptional cases. If
//                                        the parameter is not specified, the object is recorded in case
//                                        when the modification sign is set in the object form.
//
//  * RequiredFileOperationsExtension - Boolean - (optional) Shows that it
//                                        is required to enable work with files extension before executing the command. If the parameter is
//                                        not specified, the extension for work with files will not be connected.
//
Function CreateCollectionPrintCommands() Export
	
	Result = New ValueTable;
	
	// definition
	Result.Columns.Add("ID", New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	
	//////////
	// Options (optional parameters).
	
	// print manager
	Result.Columns.Add("PrintManager", New TypeDescription("String"));
	Result.Columns.Add("PrintingObjectsTypes", New TypeDescription("Array"));
	
	// Alternative command handler.
	Result.Columns.Add("Handler", New TypeDescription("String"));
	
	// Presentation
	Result.Columns.Add("Order", New TypeDescription("Number"));
	Result.Columns.Add("Picture", New TypeDescription("Picture"));
	// Names of forms for commands placement, separator - comma.
	Result.Columns.Add("FormsList", New TypeDescription("String"));
	Result.Columns.Add("PlaceProperties", New TypeDescription("String"));
	Result.Columns.Add("FormTitle", New TypeDescription("String"));
	// Names of functional options that affect the visible of the command, separator - comma.
	Result.Columns.Add("FunctionalOptions", New TypeDescription("String"));
	
	// check posting
	Result.Columns.Add("CheckPostingBeforePrint", New TypeDescription("Boolean"));
	
	// conclusion
	Result.Columns.Add("StraightToPrinter", New TypeDescription("Boolean"));
	Result.Columns.Add("SavingFormat"); // SpreadsheetDocumentFileType
	
	// settings
	// of Prohibition of user settings saving sets.
	Result.Columns.Add("OverrideUserCountSettings", New TypeDescription("Boolean"));
	Result.Columns.Add("ComplementKitWithExternalPrintForms", New TypeDescription("Boolean"));
	Result.Columns.Add("FixedKit", New TypeDescription("Boolean")); // prevent from changing the kit
	
	// additional parameters
	Result.Columns.Add("AdditionalParameters", New TypeDescription("Structure"));
	
	// Special mode
	// of default command execution the modified object is recorded before executing the command.
	Result.Columns.Add("DoNotPerformRecordInForm", New TypeDescription("Boolean"));
	
	// For use of office document templates in the web client.
	Result.Columns.Add("RequiredFileOperationsExtension", New TypeDescription("Boolean"));
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with office documents templates.

// Adds a new record about the area to parameter AreasSet.
//	
// Parameters:
//   OfficeDocumentLayout - Array - set of areas (array of structures) of office document template.
//   AreaName              - String - name of the area being added.
//   AreaType              - String - area type:
// 		Header
// 		Footer
// 		Common
// 		TableRow
// 		List
//	
// Example:
// Function OfficeDocumentLayoutAreas()
//	
// 	Areas = New Structure;
//	
// 	PrintManagement.AddAreaLongDesc(Areas,	"Header", "Header");
// 	PrintManagement.AddAreaLongDesc(Areas,	"Footer", "Footer");
// 	PrintManagement.AddAreaLongDesc(Areas,			"Title", "Common");
//	
// 	Area Return;
//	
// EndFunction
//
Procedure AddAreaLongDesc(OfficeDocumentLayoutAreas, Val AreaName, Val AreaType) Export
	
	NewArea = New Structure;
	
	NewArea.Insert("AreaName", AreaName);
	NewArea.Insert("AreaType", AreaType);
	
	OfficeDocumentLayoutAreas.Insert(AreaName, NewArea);
	
EndProcedure

// Gets in one call all necessary information for printing: templates data items,
// binary data template, description of templates areas.
// For calling the print forms from client modules according to office document templates.
//
// Parameters:
//   PrintManagerName - String - name for referring to the object manager, for example "Document.<Document name>".
//   TemplateNames       - String - template names that will form print forms.
//   ContentOfDocuments   - Array - references to the infobase objects (must be of the same type).
//
Function TemplatesAndDataObjectsForPrinting(Val PrintManagerName, Val TemplateNames, Val ContentOfDocuments) Export
	
	TemplateNameArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(StrReplace(TemplateNames, " ", ""), ",");
	
	ObjectManager = CommonUse.ObjectManagerByFullName(PrintManagerName);
	TemplatesAndData = ObjectManager.GetPrintData(ContentOfDocuments, TemplateNameArray);
	TemplatesAndData.Insert("PrintFilesLocalDirectory", GetPrintFilesLocalDirectory());
	
	Return TemplatesAndData;
	
EndFunction

// Returns a layout of the print form by a full path to the layout.
//
// Parameters:
//  FullPathToTemplate - String - full path to the layout in the format:
// 							"Document.<DocumentName>.<TemplateName>"
// 							"DataProcessor.<DataProcessorName>.<TemplateName>"
// 							"CommonTemplate.<TemplateName>".
// Returns:
//   SpreadsheetDocument - for layout of MXL type.
//  BinaryData    - for layouts DOC and ODT.
//
Function PrintedFormsTemplate(FullPathToTemplate) Export
	
	PartsWays = StrReplace(FullPathToTemplate, ".", Chars.LF);
	
	If StrLineCount(PartsWays) = 3 Then
		PathToMetadata = StrGetLine(PartsWays, 1) + "." + StrGetLine(PartsWays, 2);
		PathToMetadataObject = StrGetLine(PartsWays, 3);
	ElsIf StrLineCount(PartsWays) = 2 Then
		PathToMetadata = StrGetLine(PartsWays, 1);
		PathToMetadataObject = StrGetLine(PartsWays, 2);
	Else
		Raise StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'Layout ""%1"" is not found. Operation is aborted.'"), FullPathToTemplate);
	EndIf;
	
	Query = New Query;
	
	Query.Text = "SELECT Template AS Template, Use AS Use
					|FROM
					|	InformationRegister.UserPrintTemplates
					|WHERE
					|	Object=&Object
					|	AND	TemplateName=&TemplateName
					|	AND	Use";
	
	Query.Parameters.Insert("Object", PathToMetadata);
	Query.Parameters.Insert("TemplateName", PathToMetadataObject);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	
	SetPrivilegedMode(False);
	
	Result = Undefined;
	
	If Selection.Next() Then
		Result = Selection.Template.Get();
	Else
		If StrLineCount(PartsWays) = 3 Then
			Result = CommonUse.ObjectManagerByFullName(PathToMetadata).GetTemplate(PathToMetadataObject);
		Else
			Result = GetCommonTemplate(PathToMetadataObject);
		EndIf;
	EndIf;
	
	If Result = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(NStr("en = 'Layout ""%1"" is not found. Operation is aborted.'"), FullPathToTemplate);
	EndIf;
		
	Return Result;
	
EndFunction

// Returns the tabular document by binary data of the tabular document.
//
// Parameters:
//  DocumentBinaryData - BinaryData - binary data of the tabular document.
//
// Returns:
//  TabularDocument.
//
Function TabularDocumentByBinaryData(DocumentBinaryData) Export
	
	TempFileName = GetTempFileName();
	DocumentBinaryData.Write(TempFileName);
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(TempFileName);
	If SafeMode() = False Then
		DeleteFiles(TempFileName);
	EndIf;
	
	Return SpreadsheetDocument;
	
EndFunction

// Outdated. You should use TemplatesAndDataObjectsForPrinting.
//
Function GetTemplatesAndDataOfObjects(Val PrintManagerName, Val TemplateNames, Val ContentOfDocuments) Export
	
	Return TemplatesAndDataObjectsForPrinting(PrintManagerName, TemplateNames, ContentOfDocuments);
	
EndFunction

// Outdated. You shall use PrintFormLayout.
//
Function GetTemplate(FullPathToTemplate) Export
	
	Return PrintedFormsTemplate(FullPathToTemplate);
	
EndFunction

// Outdated. You shall use TabularDocumentByBinaryData.
//
Function GetSpreadsheetDocumentByBinaryData(BinaryData) Export
	
	TempFileName = GetTempFileName();
	BinaryData.Write(TempFileName);
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(TempFileName);
	If SafeMode() = False Then
		DeleteFiles(TempFileName);
	EndIf;
	
	Return SpreadsheetDocument;
	
EndFunction

// Returns binary data to generate a QR code.
//
// Parameters:
//  QRString         - String - data to be placed to the QR code.
//
//  CorrectionLevel - Number - default level of the image at which this QR code
//                             can be 100% recognized.
//                     The parameter should be of type integer and accept 1 out of 4 acceptable values:
//                     0(7% errors), 1(15% errors), 2(25% errors), 3(35% errors).
//
//  Size           - Number - specifies the side length of the resulting image in pixels.
//                     If minimum possible size of the image exceeds this parameter - code will not be generated.
//
//  ErrorText      - String - in this parameter the description of an error is placed (if any).
//
// Returns:
//  BinaryData  - buffer containing the bytes of PNG image of the QR code.
// 
// Example:
//  
//  // Send to print the QR code containing the information encrypted by UFEBS.
//
//  QRString = PrintManagement.FormatStringUFEBS(PaymentDetails);
//  ErrorText = "";
//  QRCodeData = PrintManagement.QRCodeData(QRString, 0, 190, ErrorText);
//  If Not
//      IsBlankString(ErrorText) CommonUseClientServer.MessageToUser(ErrorText);
//  EndIf;
//
//  QRCodePicture = New Picture(QRCodeData);
//  TemplateArea.Drawings.QRCode.Picture = PictureOfQRCode;
//
Function QRCodeData(QRString, CorrectionLevel, Size) Export
	
	Cancel = False;
	
	QRCodeGenerator = ComponentQRCodeGeneration(Cancel);
	If Cancel Then
		Return Undefined;
	EndIf;
	
	Try
		BinaryDataImages = QRCodeGenerator.GenerateQRCode(QRString, CorrectionLevel, Size);
	Except
		WriteLogEvent(NStr("en = 'Creating QR code'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return BinaryDataImages;
	
EndFunction

// Creates a format string according to "Uniform format for electronic banking messages"
// to display it as a QR code.
//
// Parameters:
// DocumentData  - Structure - contains values of the document fields.
// 				- Document data will be encoded according to the standard "FINANCIAL TRANSACTIONS STANDARDS Characters of two-dimensional barcode for payments by private persons".
// 				- DocumentData should contain the information in the fields described below.
//
// 				- Required fields of the structure.
// 	* PayeeText             - Payment recipient name         - Max. 160 characters;
// 	* PayeeAccountNumber        - Recipient bank account          - Max. 20 characters;
// 	* PayeeBankDescription - Recipient bank name   - Max. 45 symbols;
// 	* PayeeBankBIC          - BIN                                     - Max. 9 symbols;
// 	* PayeeBankAcc         - correspondent account number of the payee bank - Max. 20 characters;
// 				- Additional structure fields.
// 	* AmountAsNumber         - Payment amount, rub                 - Max. 16 symbols.
// 	* PaymentDestination   - Payment name (purpose)       - Max. 210 symbols;
// 	* PayeeTIN       - Payee TIN                  - Max. 12 characters;
// 	* PayerTIN      - Payer's TIN                         - Max. 12 characters;
// 	* CompilerStatus   - Status of the Payment Document's Author - Max. 2 symbols;
// 	* PayeeKPP       - Payee KPP                  - Max. 9 symbols.
// 	* BKCode               - KBK                                     - Max. 20 characters;
// 	* OKTMOCode            - OKTMOCode code                            - Max. 11 symbols;
// 	* BasisIndicator - Tax basis            - Max. 2 symbols;
// 	* PeriodIndicator   - Fiscal Period                        - Max. 10 symbols;
// 	* NumberIndicator    - Document No.                         - Max. 15 symbols;
// 	* DateIndicator      - Document date                          - Max. 10 symbol.
// 	* TypeIndicator      - Payment type                             - Max. 2 symbols.
// 				- Other additional fields.
// 	* PayerSurname               - Payer name.
// 	* PayerName                   - Payer name.
// 	* PayerPatronymic              - Payer patronymic.
// 	* PayerAddress                 - Payer address.
// 	* BudgetRecipientAccount  - Budget recipient account.
// 	* PaymentDocumentIndex        - Payment document index.
// 	* INILA                            - personal account No in the system of personified accounting in RPF - INILA.
// 	* ContractNumber                    - Contract number.
// 	* PayerAccountNumber    - Number of payer personal account in the company (in PU accounting system).
// 	* ApartmentNumber                    - Apartment number.
// 	* TelephoneNumber                    - Telephone number.
// 	* PayerKind                   - Kind of payer DUL.
// 	* PayerNumber                  - DUL number of payer.
// 	* ChildInitials                       - Full name of child/student.
// 	* BirthDate                     - Date of birth.
// 	* PaymentDate                      - Payment deadline/invoice date.
// 	* PaymentPeriod                     - Payment period .
// 	* PaymentKind                       - Payment kind.
// 	* ServiceCode                        - Service code/metering device name.
// 	* MeteringDeviceNumber                - Metering device number.
// 	* MeteredValue            - Metered values.
// 	* NotificationNumber                   - Number of notification, accrual, account.
// 	* NotificationDate                    - Date of notice/accrual/account/regulation (for STSI).
// 	* InstitutionNumber                  - Institution number (educational, medical).
// 	* GroupNumber                      - Group number in kindergarten/school.
// 	* TeacherInitials                 - Initials of a teacher, a specialist who provides the service.
// 	* InsuranceAmount                   - Amount of insurance/additional service/Penalties amount (in copecks).
// 	* OrderNumber               - Resolution number (for STSI).
// 	* EnforcementNumber - Enforcement number.
// 	* PaymentKindCode                   - Code of payment kind (e.g. for payments to Rosreestr).
// 	* AccrualIdentifier          - Unique accrual identifier.
// 	* TechnicalCode                   - Technical code for filling by a provider of services (recommended).
//                                           Can be used by host company
//                                           to call appropriate processing IT system.
//                                           Code values are listed below.
//
// Purpose			code Payment purpose
// 	name.
//	
// 		01				Mobile communication, landline phone.
// 		02				Housing and utility services.
// 		03				STSI, taxes, duties, budgetary payments.
// 		04				Security services
// 		05				Services provided by FMS.
// 		06				RPF
// 		07				Loan repayments
// 		08				Educational institutions.
// 		09				Internet and
// 		TV				10 Electronic
// 		money				11 Recreation and travel.
// 		12				Investments and insurance.
// 		13				Sport and
// 		health				14 Philanthropic and non-governmental organizations
// 		15				Other services
//
// Returns:
//   String - data string in format UFEBS.
//
Function FormatStringUFEBS(DocumentData) Export
	
	ErrorText = "";
	RequiredAttributesString = RequiredAttributesString(DocumentData, ErrorText);
	
	If IsBlankString(RequiredAttributesString) Then
		CommonUseClientServer.MessageToUser(ErrorText, , , ,);
		Return "";
	EndIf;
	
	PresentationsAndAttributesStructure = PresentationsAndAttributesStructure();
	StringAdditionalAttributes = "";
	AdditionalAttributes = New Structure;
	AddAdditionalAttributes(AdditionalAttributes);
	
	For Each Item IN AdditionalAttributes Do
		
		If Not DocumentData.Property(Item.Key) Then
			DocumentData.Insert(Item.Key, "");
			Continue;
		EndIf;
		
		If ValueIsFilled(DocumentData[Item.Key]) Then
			If Item.Key = "AmountAsNumber" Then
				ValueByString = Format(DocumentData.AmountAsNumber * 100, "NG=");
			Else
				ValueByString = StrReplace(TrimAll(String(DocumentData[Item.Key])), "|", "");
			EndIf;
			StringAdditionalAttributes = StringAdditionalAttributes + PresentationsAndAttributesStructure[Item.Key]
			                                 + "=" + ValueByString + "|";
		EndIf;
	EndDo;
	
	If Not IsBlankString(StringAdditionalAttributes) Then
		StringLength = StrLen(StringAdditionalAttributes);
		StringAdditionalAttributes = Mid(StringAdditionalAttributes, 1, StringLength - 1);
	EndIf;

	OtherAdditionalAttributes = New Structure;
	AddOtherAdditionalAttributes(OtherAdditionalAttributes);
	OtherAdditionalAttributesString = "";
	
	For Each Item IN OtherAdditionalAttributes Do
		
		If Not DocumentData.Property(Item.Key) Then
			DocumentData.Insert(Item.Key, "");
			Continue;
		EndIf;
		
		If ValueIsFilled(DocumentData[Item.Key]) Then
			ValueByString = StrReplace(TrimAll(String(DocumentData[Item.Key])), "|", "");
			OtherAdditionalAttributesString = OtherAdditionalAttributesString
			                                       + PresentationsAndAttributesStructure[Item.Key] + "=" + ValueByString
			                                       + "|";
		EndIf;
	EndDo;
	
	If Not IsBlankString(OtherAdditionalAttributesString) Then
		StringLength = StrLen(OtherAdditionalAttributesString);
		OtherAdditionalAttributesString = Mid(OtherAdditionalAttributesString, 1, StringLength - 1);
	EndIf;
	
	TotalRow = RequiredAttributesString
	                 + ?(IsBlankString(StringAdditionalAttributes), "", "|" + StringAdditionalAttributes)
	                 + ?(IsBlankString(OtherAdditionalAttributesString), "", "|" + OtherAdditionalAttributesString);
	
	Return TotalRow;
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"PrintManagement");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"PrintManagement");
	
	If CommonUse.SubsystemExists("StandardSubsystems.CurrentWorks") Then
		ServerHandlers["StandardSubsystems.CurrentWorks\AtFillingToDoList"].Add(
			"PrintManagement");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.5";
	Handler.Procedure = "PrintManagement.ResetFormUserSettingsPrintDocuments";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.22";
	Handler.Procedure = "PrintManagement.ConvertCustomTemplatesMXLBinaryDataToTabularDocuments";
	
EndProcedure

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(permissions()));
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  CurrentWorks - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(CurrentWorks) Export
	
	ModuleCurrentWorksService = CommonUse.CommonModule("CurrentWorksService");
	If Not AccessRight("Edit", Metadata.InformationRegisters.UserPrintTemplates)
		Or ModuleCurrentWorksService.WorkDisabled("PrintFormsTemplates") Then
		Return;
	EndIf;
	
	// If there is no administration section, the to-do is not added.
	Subsystem = Metadata.Subsystems.Find("Administration");
	If Subsystem <> Undefined
		AND Not AccessRight("view", Subsystem)
		AND Not CommonUse.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
		Return;
	EndIf;
	
	OutputToDo = True;
	CheckedForVersion = CommonSettingsStorage.Load("CurrentWorks", "PrintForms");
	If CheckedForVersion <> Undefined Then
		VersionArray  = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Metadata.Version, ".");
		CurrentVersion = VersionArray[0] + VersionArray[1] + VersionArray[2];
		If CheckedForVersion = CurrentVersion Then
			OutputToDo = False; // Print forms are checked in the current version.
		EndIf;
	EndIf;
	
	QuantityCustomLayouts = UsedCustomLayoutsCount();
	
	// Add to-do.
	Work = CurrentWorks.Add();
	Work.ID = "PrintFormsTemplates";
	Work.ThereIsWork      = OutputToDo AND QuantityCustomLayouts > 0;
	Work.Presentation = NStr("en = 'Print form templates'");
	Work.Quantity    = QuantityCustomLayouts;
	Work.Form         = "InformationRegister.UserPrintTemplates.Form.PrintingFormsChecking";
	Work.Owner      = "CheckCompatibilityWithCurrentVersion";
	
	// Check if there is a to-do group. If there is no group - add.
	ToDosGroup = CurrentWorks.Find("CheckCompatibilityWithCurrentVersion", "ID");
	If ToDosGroup = Undefined Then
		ToDosGroup = CurrentWorks.Add();
		ToDosGroup.ID = "CheckCompatibilityWithCurrentVersion";
		ToDosGroup.ThereIsWork      = Work.ThereIsWork;
		ToDosGroup.Presentation = NStr("en = 'Check compatibility'");
		If Work.ThereIsWork Then
			ToDosGroup.Quantity = Work.Quantity;
		EndIf;
		ToDosGroup.Owner = Subsystem;
	Else
		If Not ToDosGroup.ThereIsWork Then
			ToDosGroup.ThereIsWork = Work.ThereIsWork;
		EndIf;
		
		If Work.ThereIsWork Then
			ToDosGroup.Quantity = ToDosGroup.Quantity + Work.Quantity;
		EndIf;
	EndIf;
	
EndProcedure

// Returns permissions list to import banks classifier from RBC website.
//
// Returns:
//  Array.
//
Function permissions()
	
	permissions = New Array;
	permissions.Add( 
		WorkInSafeMode.PermissionToUseExternalComponent("CommonTemplate.QRCodePrintComponent", NStr("en = 'Print QR codes.'"))
	);
	
	Return permissions;
	
EndFunction

// Resets user settings of print forms number and order.
Procedure ResetFormPrintDocumentsUserSettings() Export
	CommonUse.CommonSettingsStorageDelete("PrintFormsSettings", Undefined, Undefined);
EndProcedure

// Converts user MXL templates stored as binary data into tabular documents.
Procedure ConvertBinaryDataOfCustomTemplatesMXLInSpreadsheetDocuments() Export
	
	QueryText = 
	"SELECT
	|	UserPrintTemplates.TemplateName,
	|	UserPrintTemplates.Object,
	|	UserPrintTemplates.Template,
	|	UserPrintTemplates.Use
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates";
	
	Query = New Query(QueryText);
	SelectionTemplates = Query.Execute().Select();
	
	While SelectionTemplates.Next() Do
		If Left(SelectionTemplates.TemplateName, 6) = "PF_MXL" Then
			TempFileName = GetTempFileName();
			
			TemplateBinaryData = SelectionTemplates.Template.Get();
			If TypeOf(TemplateBinaryData) <> Type("BinaryData") Then
				Continue;
			EndIf;
			
			TemplateBinaryData.Write(TempFileName);
			
			SpreadsheetDocumentWasRead = True;
			SpreadsheetDocument = New SpreadsheetDocument;
			Try
				SpreadsheetDocument.Read(TempFileName);
			Except
				SpreadsheetDocumentWasRead = False; // This file is not a tabular document, delete it.
			EndTry;
			
			Record = InformationRegisters.UserPrintTemplates.CreateRecordManager();
			FillPropertyValues(Record, SelectionTemplates, , "Template");
			
			If SpreadsheetDocumentWasRead Then
				Record.Template = New ValueStorage(SpreadsheetDocument, New Deflation(9));
				Record.Write();
			Else
				Record.Delete();
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Returns a reference to an object-source of external print form.
//
// Parameters:
//  ID              - String - form identifier;
//  FullMetadataObjectName - String - full name of the metadata object for which
//                                        the reference to external print form source shall be received.
//
// Returns:
//  Refs.
Function ExternalPrintForm(ID, FullMetadataObjectName)
	ExternalPrintFormRef = Undefined;
	
	OnExternalPrintFormReceiving(ID, FullMetadataObjectName, ExternalPrintFormRef);
	
	Return ExternalPrintFormRef;
EndFunction

// Generate print forms.
Function GeneratePrintForms(Val PrintManagerName, Val TemplateNames, Val ObjectsArray, Val PrintParameters, 
	AllowablePrintObjectsTypes = Undefined) Export
	
	PrintFormsCollection = PrepareCollectionOfPrintForms(New Array);
	PrintObjects = New ValueList;
	OutputParameters = PrepareOutputParametersStructure();
	
	If TypeOf(TemplateNames) = Type("String") Then
		TemplateNames = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(TemplateNames);
	Else // Type("Array")
		TemplateNames = CommonUseClientServer.CopyArray(TemplateNames);
	EndIf;
	
	ExternalPrintFormsPrefix = "ExternalPrintForm.";
	
	ExternalSourceOfPrintedForms = PrintManagerName;
	If CommonUse.IsReference(TypeOf(ObjectsArray)) Then
		ExternalSourceOfPrintedForms = ObjectsArray.Metadata().FullName();
	Else
		If ObjectsArray.Count() > 0 Then
			ExternalSourceOfPrintedForms = ObjectsArray[0].Metadata().FullName();
		EndIf;
	EndIf;
	ExternalPrintForms = PrintFormsListFromExternalSources(ExternalSourceOfPrintedForms);
	
	// Add external print forms to the set.
	AddedExternalPrintForms = New Array;
	If TypeOf(PrintParameters) = Type("Structure") 
		AND PrintParameters.Property("ComplementKitWithExternalPrintForms") 
		AND PrintParameters.ComplementKitWithExternalPrintForms Then 
		
		ExternalIdentifiersPrintedForms = ExternalPrintForms.UnloadValues();
		For Each ID IN ExternalIdentifiersPrintedForms Do
			TemplateNames.Add(ExternalPrintFormsPrefix + ID);
			AddedExternalPrintForms.Add(ExternalPrintFormsPrefix + ID);
		EndDo;
	EndIf;
	
	For Each TemplateName IN TemplateNames Do
		// Check existence of already printed forms.
		FoundPrintForm = PrintFormsCollection.Find(TemplateName, "TemplateName");
		If FoundPrintForm <> Undefined Then
			LastAddedPrintForm = PrintFormsCollection[PrintFormsCollection.Count() - 1];
			If LastAddedPrintForm.TemplateName = FoundPrintForm.TemplateName Then
				LastAddedPrintForm.Copies = LastAddedPrintForm.Copies + 1;
			Else
				CopyPrintedForms = PrintFormsCollection.Add();
				FillPropertyValues(CopyPrintedForms, FoundPrintForm);
				CopyPrintedForms.Copies = 1;
			EndIf;
			Continue;
		EndIf;
		
		// Searching the indication of print manager in the name of a print form.
		NameOfPrintManager = "";
		ID = TemplateName;
		ExternalPrintForm = Undefined;
		If Find(ID, ExternalPrintFormsPrefix) > 0 Then // this external print form
			ID = Mid(ID, StrLen(ExternalPrintFormsPrefix) + 1);
			ExternalPrintForm = ExternalPrintForms.FindByValue(ID);
		ElsIf Find(ID, ".") > 0 Then // Additional print manager is specified.
			Position = StringFunctionsClientServer.FindCharFromEnd(ID, ".");
			NameOfPrintManager = Left(ID, Position - 1);
			ID = Mid(ID, Position + 1);
		EndIf;
		
		// Definition of internal print manager.
		UsedPrintManager = NameOfPrintManager;
		If IsBlankString(UsedPrintManager) Then
			UsedPrintManager = PrintManagerName;
		EndIf;
		
		// Checking the correspondence of the objects to be printed and selected print form.
		ExpectedObjectType = Undefined;
		
		ObjectsCorrespondingToPrintForm = ObjectsArray;
		If AllowablePrintObjectsTypes <> Undefined AND AllowablePrintObjectsTypes.Count() > 0 Then
			If TypeOf(ObjectsArray) = Type("Array") Then
				ObjectsCorrespondingToPrintForm = New Array;
				For Each Object IN ObjectsArray Do
					If AllowablePrintObjectsTypes.Find(TypeOf(Object)) = Undefined Then
						MessagePrintingFormIsUnavailable(Object);
					Else
						ObjectsCorrespondingToPrintForm.Add(Object);
					EndIf;
				EndDo;
				If ObjectsCorrespondingToPrintForm.Count() = 0 Then
					ObjectsCorrespondingToPrintForm = Undefined;
				EndIf;
			ElsIf CommonUse.ReferenceTypeValue(ObjectsArray) Then // not an array is passed
				If AllowablePrintObjectsTypes.Find(TypeOf(ObjectsArray)) = Undefined Then
					MessagePrintingFormIsUnavailable(ObjectsArray);
					ObjectsCorrespondingToPrintForm = Undefined;
				EndIf;
			EndIf;
		EndIf;
		
		TemporaryCollectionForOnePrintForm = PrepareCollectionOfPrintForms(ID);
		
		// Calling procedure Print from print manager.
		If ExternalPrintForm <> Undefined Then
			// Print manager in the external print form.
			ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.PrintByExternalSource(
				ExternalPrintForm(ExternalPrintForm.Value, ExternalSourceOfPrintedForms),
				New Structure("CommandID, DestinationObjects", ExternalPrintForm.Value, ObjectsCorrespondingToPrintForm),
				TemporaryCollectionForOnePrintForm,
				PrintObjects,
				OutputParameters);
		Else
			If Not IsBlankString(UsedPrintManager) Then
				PrintManager = CommonUse.ObjectManagerByFullName(UsedPrintManager);
				// Printing an internal print form.
				If ObjectsCorrespondingToPrintForm <> Undefined Then
					PrintManager.Print(ObjectsCorrespondingToPrintForm, PrintParameters, TemporaryCollectionForOnePrintForm, 
						PrintObjects, OutputParameters);
				Else
					TemporaryCollectionForOnePrintForm[0].SpreadsheetDocument = New SpreadsheetDocument;
				EndIf;
			EndIf;
		EndIf;
		
		// Check whether a print form collection received from the print manager is filled in correctly.
		For Each PrintFormDescription IN TemporaryCollectionForOnePrintForm Do
			CommonUseClientServer.Validate(
				TypeOf(PrintFormDescription.Copies) = Type("Number") AND PrintFormDescription.Copies > 0,
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'Specify a number of instances for print form ""%1"".'"),
					?(IsBlankString(PrintFormDescription.TemplateSynonym), PrintFormDescription.TemplateName, PrintFormDescription.TemplateSynonym)));
		EndDo;
				
		// updating a collection
		Cancel = TemporaryCollectionForOnePrintForm.Count() = 0;
		// One print form is assumed but for backward compatibility the entire collection is accepted.
		For Each TemporaryPrintForm IN TemporaryCollectionForOnePrintForm Do 
			If TemporaryPrintForm.SpreadsheetDocument <> Undefined Then
				PrintForm = PrintFormsCollection.Add();
				FillPropertyValues(PrintForm, TemporaryPrintForm);
				If TemporaryCollectionForOnePrintForm.Count() = 1 Then
					PrintForm.TemplateName = TemplateName;
					PrintForm.NameUPPER = Upper(TemplateName);
				EndIf;
			Else
				// An error occurred when generating the print form.
				Cancel = True;
			EndIf;
		EndDo;
		
		// Calling an exception if an error occurs.
		If Cancel Then
			ErrorMessageText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en = 'When generating print form ""%1"", an error occurred. Contact your administrator.'"), TemplateName);
			Raise ErrorMessageText;
		EndIf;
		
	EndDo;
	
	// Setting the number of copies of the tabular documents.
	For Each PrintForm IN PrintFormsCollection Do
		If AddedExternalPrintForms.Find(PrintForm.TemplateName) <> Undefined Then
			PrintForm.Copies = 0; // For automatically added forms.
		EndIf;
		If PrintForm.SpreadsheetDocument <> Undefined Then
			PrintForm.SpreadsheetDocument.Copies = PrintForm.Copies;
		EndIf;
	EndDo;
	
	Result = New Structure;
	Result.Insert("PrintFormsCollection", PrintFormsCollection);
	Result.Insert("PrintObjects", PrintObjects);
	Result.Insert("OutputParameters", OutputParameters);
	Return Result;
	
EndFunction

// Generate print forms for output directly to a printer.
//
Function GeneratePrintFormsForQuickPrint(PrintManagerName, TemplateNames, ObjectsArray, PrintParameters) Export
	
	Result = New Structure("DocumentsTable,PrintObjects,OutputParameters,Cancel", 
		Undefined, Undefined, Undefined, False);
		
	If Not AccessRight("Output", Metadata) Then
		Result.Cancel = True;
		Return Result;
	EndIf;
	
	PrintForms = GeneratePrintForms(PrintManagerName, TemplateNames, ObjectsArray, PrintParameters);
		
	DocumentsTable = New ValueList;
	For Each PrintForm IN PrintForms.PrintFormsCollection Do
		If (TypeOf(PrintForm.SpreadsheetDocument) = Type("SpreadsheetDocument")) AND (PrintForm.SpreadsheetDocument.TableHeight <> 0) Then
			DocumentsTable.Add(PrintForm.SpreadsheetDocument, PrintForm.TemplateSynonym);
		EndIf;
	EndDo;
	
	Result.DocumentsTable = DocumentsTable;
	Result.PrintObjects      = PrintForms.PrintObjects;
	Result.OutputParameters    = PrintForms.OutputParameters;
	Return Result;
	
EndFunction

// Generate print forms to send directly
// to printer in server mode in the standard application.
//
Function GeneratePrintFormsForQuickPrintOrdinaryApplication(PrintManagerName, TemplateNames, ObjectsArray, PrintParameters) Export
	
	Result = New Structure("Address,PrintObjects,OutputParameters,Cancel", 
		Undefined, Undefined, Undefined, False);
		
	PrintForms = GeneratePrintFormsForQuickPrint(PrintManagerName, TemplateNames, ObjectsArray, PrintParameters);
	
	If PrintForms.Cancel Then
		Result.Cancel = PrintForms.Cancel;
		Return Result;
	EndIf;
	
	Result.PrintObjects = New Map;
	
	For Each PrintObject IN PrintForms.PrintObjects Do
		Result.PrintObjects.Insert(PrintObject.Presentation, PrintObject.Value);
	EndDo;
	
	Result.Address = PutToTempStorage(PrintForms.DocumentsTable);
	Return Result;
	
EndFunction

// Prepare a collection of print forms - table of values used when generating print form.
//
Function PrepareCollectionOfPrintForms(Val TemplateNames) Export
	
	Templates = New ValueTable;
	Templates.Columns.Add("TemplateName");
	Templates.Columns.Add("NameUPPER");
	Templates.Columns.Add("TemplateSynonym");
	Templates.Columns.Add("SpreadsheetDocument");
	Templates.Columns.Add("Copies");
	Templates.Columns.Add("Picture");
	Templates.Columns.Add("FullPathToTemplate");
	Templates.Columns.Add("FileNamePrintedForm");
	
	If TypeOf(TemplateNames) = Type("String") Then
		TemplateNames = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(TemplateNames);
	EndIf;
	
	For Each TemplateName IN TemplateNames Do
		Template = Templates.Find(TemplateName, "TemplateName");
		If Template = Undefined Then
			Template = Templates.Add();
			Template.TemplateName = TemplateName;
			Template.NameUPPER = Upper(TemplateName);
			Template.Copies = 1;
		Else
			Template.Copies = Template.Copies + 1;
		EndIf;
	EndDo;
	
	Return Templates;
	
EndFunction

// Prepare the structure of output parameters for the manager of the object that generates print forms.
//
Function PrepareOutputParametersStructure() Export
	
	OutputParameters = New Structure;
	OutputParameters.Insert("PrintBySetsAvailable", False); // not used
	
	LetterParametersStructure = New Structure("Recipient,Subject,Text", Undefined, "", "");
	OutputParameters.Insert("SendingParameters", LetterParametersStructure);
	
	Return OutputParameters;
	
EndFunction

// Returns the path from the temporary storage to the directory used when printing.
//
Function GetPrintFilesLocalDirectory() Export
	
	Value = CommonUse.CommonSettingsStorageImport("PrintFilesLocalDirectory");
	Return ?(Value = Undefined, "", Value);
	
EndFunction

// Stores the path in temporary storage to the directory used when printing.
// Parameters:
//  Directory - String - path to print directory.
//
Procedure SaveLocalDirectoryOfPrintFiles(Directory) Export
	
	CommonUse.CommonSettingsStorageSave("PrintFilesLocalDirectory", , Directory);
	
EndProcedure

// Returns the table of possible formats for tabular document saving.
//
// Return
//  value ValuesTable:
//                   SpreadsheetDocumentFileType - SpreadsheetDocumentFileType                 - value
//                                                                                               in
//                                                                                               the platform corresponding format;
//                   Ref                      - EnumRef.SaveReportFormats - ref
//                                                                                               to metadata
//                                                                                               where presentation is stored;
//                   Presentation               - String -                                    - presentation
//                                                          file type (populated from enum);
//                   Extension                  - String -                                    - file type
//                                                          for the operating system;
//                   Picture                    - Picture                                    - icon format.
//
// Note: the table of formats can be
// overridden in the procedure PrintManagementOverridable.OnSpreadsheetDocumentSavingFormatsSettingsFilling().
//
Function SpreadsheetDocumentSavingFormatsSettings() Export
	
	FormatsTable = New ValueTable;
	
	FormatsTable.Columns.Add("SpreadsheetDocumentFileType", New TypeDescription("SpreadsheetDocumentFileType"));
	FormatsTable.Columns.Add("Ref", New TypeDescription("EnumRef.SaveReportFormats"));
	FormatsTable.Columns.Add("Presentation", New TypeDescription("String"));
	FormatsTable.Columns.Add("Extension", New TypeDescription("String"));
	FormatsTable.Columns.Add("Picture", New TypeDescription("Picture"));

	// Document PDF (.pdf)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.PDF;
	NewFormat.Ref = Enums.SaveReportFormats.PDF;
	NewFormat.Extension = "pdf";
	NewFormat.Picture = PictureLib.PDFFormat;
	
	// Microsoft Excel Sheet 2007 (.xls)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLSX;
	NewFormat.Ref = Enums.SaveReportFormats.XLSX;
	NewFormat.Extension = "xlsx";
	NewFormat.Picture = PictureLib.MSExcel2007Format;

	// Microsoft Excel Sheet 97-2003 (.xls)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLS;
	NewFormat.Ref = Enums.SaveReportFormats.XLS;
	NewFormat.Extension = "xls";
	NewFormat.Picture = PictureLib.MSExcelFormat;

	// Spreadsheet document OpenDocument (.ods).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ODS;
	NewFormat.Ref = Enums.SaveReportFormats.ODS;
	NewFormat.Extension = "ods";
	NewFormat.Picture = PictureLib.OpenOfficeCalcFormat;
	
	// Tabular document (.mxl)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.MXL;
	NewFormat.Ref = Enums.SaveReportFormats.MXL;
	NewFormat.Extension = "mxl";
	NewFormat.Picture = PictureLib.MXLFormat;

	// Word document 2007 (.docx)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.DOCX;
	NewFormat.Ref = Enums.SaveReportFormats.DOCX;
	NewFormat.Extension = "docx";
	NewFormat.Picture = PictureLib.MSWord2007Format;
	
	// Web-page (.html)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.HTML5;
	NewFormat.Ref = Enums.SaveReportFormats.HTML;
	NewFormat.Extension = "html";
	NewFormat.Picture = PictureLib.HTMLFormat;
	
	// Text document UTF8 (.txt).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.TXT;
	NewFormat.Ref = Enums.SaveReportFormats.TXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;
	
	// Text document ANSI (.txt).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ANSITXT;
	NewFormat.Ref = Enums.SaveReportFormats.ANSITXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;

	// Additional formats / changing of the current list.
	PrintManagementOverridable.OnSpreadsheetDocumentSavingFormatsSettingsFilling(FormatsTable);
	
	For Each SavingFormat IN FormatsTable Do
		SavingFormat.Presentation = String(SavingFormat.Ref);
	EndDo;
		
	Return FormatsTable;
	
EndFunction

// Creates submenu "Print" in the form and adds the print commands to it.
// If there is only one print command, a button with a print form name is added instead of a submenu.
Procedure AddPrintCommands(Form, PrintCommands, Val CommandsPlacementPlace = Undefined)
	
	If CommandsPlacementPlace = Undefined Then
		CommandsPlacementPlace = Form.CommandBar;
	EndIf;
	
	OnePrintCommand = PrintCommands.Count() = 1;
	If CommandsPlacementPlace.Type = FormGroupType.Popup Then
		If OnePrintCommand Then
			CommandsPlacementPlace.Type = FormGroupType.ButtonGroup;
		EndIf;
	Else
		If Not OnePrintCommand Then
			PopupPrint = Form.Items.Add(CommandsPlacementPlace.Name + "PopupPrint", Type("FormGroup"), CommandsPlacementPlace);
			PopupPrint.Type = FormGroupType.Popup;
			PopupPrint.Title = NStr("en = 'Print'");
			PopupPrint.Picture = PictureLib.Print;
			
			CommandsPlacementPlace = PopupPrint;
		EndIf;
	EndIf;
	
	For Each DetailsPrintCommands IN PrintCommands Do
		NumberCommands = DetailsPrintCommands.Owner().IndexOf(DetailsPrintCommands);
		CommandName = CommandsPlacementPlace.Name + "PrintCommand" + NumberCommands;
		
		FormCommand = Form.Commands.Add(CommandName);
		FormCommand.Action = "Attachable_ExecutePrintCommand";
		FormCommand.Title = DetailsPrintCommands.Presentation;
		FormCommand.ModifiesStoredData = False;
		FormCommand.Representation = ButtonRepresentation.PictureAndText;
		
		If ValueIsFilled(DetailsPrintCommands.Picture) Then
			FormCommand.Picture = DetailsPrintCommands.Picture;
		ElsIf OnePrintCommand Then
			FormCommand.Picture = PictureLib.Print;
		EndIf;
		
		DetailsPrintCommands.CommandNameOnForm = CommandName;
		
		NewItem = Form.Items.Add(CommandsPlacementPlace.Name + CommandName, Type("FormButton"), CommandsPlacementPlace);
		NewItem.Type = FormButtonType.CommandBarButton;
		NewItem.CommandName = CommandName;
	EndDo;
	
EndProcedure

// Returns the command description according to the name of the form.
// 
// Return
//  value Structure - table row from function FormPrintCommands transformed into a structure.
Function DetailsPrintCommands(CommandName, AddressPrintingCommandsInTemporaryStorage) Export
	
	PrintCommands = GetFromTempStorage(AddressPrintingCommandsInTemporaryStorage);
	For Each PrintCommand IN PrintCommands.FindRows(New Structure("CommandNameOnForm", CommandName)) Do
		Return CommonUse.ValueTableRowToStructure(PrintCommand);
	EndDo;
	
EndFunction

// Filters a list of print commands according to the set functional options.
Procedure DetermineVisiblePrintCommandsForFunctionalOptions(PrintCommands, Form)
	For NumberCommands = -PrintCommands.Count() + 1 To 0 Do
		DetailsPrintCommands = PrintCommands[-NumberCommands];
		FunctionalOptionsPrintCommands = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DetailsPrintCommands.FunctionalOptions, ",", True);
		CommandVisible = FunctionalOptionsPrintCommands.Count() = 0;
		For Each FunctionalOption IN FunctionalOptionsPrintCommands Do
			If TypeOf(Form) = Type("ManagedForm") Then
				CommandVisible = CommandVisible Or Form.GetFormFunctionalOption(FunctionalOption);
			Else
				CommandVisible = CommandVisible Or GetFunctionalOption(FunctionalOption);
			EndIf;
			
			If CommandVisible Then
				Break;
			EndIf;
		EndDo;
		DetailsPrintCommands.HiddenByFunctionalOptions = Not CommandVisible;
	EndDo;
EndProcedure

// Saves a user print layout in the info base.
Procedure WriteTemplate(MetadataObjectTemplateName, AddressTemplateInTemporaryStorage) Export
	Template = GetFromTempStorage(AddressTemplateInTemporaryStorage);
	
	NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(MetadataObjectTemplateName, ".");
	TemplateName = NameParts[NameParts.UBound()];
	
	OwnerName = "";
	For PartNumber = 0 To NameParts.UBound()-1 Do
		If Not IsBlankString(OwnerName) Then
			OwnerName = OwnerName + ".";
		EndIf;
		OwnerName = OwnerName + NameParts[PartNumber];
	EndDo;
	
	Record = InformationRegisters.UserPrintTemplates.CreateRecordManager();
	Record.Object = OwnerName;
	Record.TemplateName = TemplateName;
	Record.Use = True;
	Record.Template = New ValueStorage(Template, New Deflation(9));
	Record.Write();
EndProcedure

Function RequiredAttributesString(DocumentData, MessageText)
	
	MandatoryAttributes = New Structure();
	PresentationsAndAttributesStructure = PresentationsAndAttributesStructure();
	AddMandatoryAttributes(MandatoryAttributes);
	
	If Not ValueIsFilled(DocumentData.PayeeBankAcc) Then
		DocumentData.PayeeBankAcc = "0";
	EndIf;
	
	ServiceData = "ST00012";
	MandatoryData = "";
	
	For Each Item IN MandatoryAttributes Do
		If Not ValueIsFilled(DocumentData[Item.Key]) Then
			MessageText = NStr("en = 'Required attribute is not filled in: %1'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Item.Key);
			Return "";
		EndIf;
		
		ValueByString = StrReplace(TrimAll(String(DocumentData[Item.Key])), "|", "");
		
		MandatoryData = MandatoryData + "|" + PresentationsAndAttributesStructure[Item.Key] + "="
		                     + ValueByString;
		
	EndDo;
	
	If StrLen(MandatoryData) > 300 Then
		Pattern = NStr("en = 'Cannot generate QR code for
		                    |document %1 A line of required attributes must
		                    |be shorter than 300 characters: ""%2""'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(Pattern,
		                                                                         DocumentData.Ref,
		                                                                         MandatoryData);
		CommonUseClientServer.MessageToUser(MessageText);
		Return "";
	EndIf;
	
	Return ServiceData + MandatoryData;
	
EndFunction

Function PresentationsAndAttributesStructure()
	
	ReturnStructure = New Structure();
	
	ReturnStructure.Insert("PayeeText",             "Name");
	ReturnStructure.Insert("RecipientAccountNumber",        "PersonalAcc");
	ReturnStructure.Insert("PayeeBankDescription", "BankName");
	ReturnStructure.Insert("RecipientBankBIC",          "BIC");
	ReturnStructure.Insert("PayeeBankAcc",         "CorrespAcc");
	
	ReturnStructure.Insert("AmountAsNumber",         "Sum");
	ReturnStructure.Insert("PaymentDestination",   "Purpose");
	ReturnStructure.Insert("PayeeTIN",       "PayeeTIN");
	ReturnStructure.Insert("PayerTIN",      "PayerTIN");
	ReturnStructure.Insert("AuthorStatus",   "DrawerStatus");
	ReturnStructure.Insert("PayeeKPP",       "KPP");
	ReturnStructure.Insert("BKCode",               "CBC");
	ReturnStructure.Insert("OKTMOCode",            "OKTMO");
	ReturnStructure.Insert("BasisIndicator", "PaytReason");
	ReturnStructure.Insert("PeriodIndicator",   "TaxPeriod");
	ReturnStructure.Insert("NumberIndicator",    "DocNo");
	ReturnStructure.Insert("DateIndicator",      "DocDate");
	ReturnStructure.Insert("TypeIndicator",      "TaxPaytKind");
	
	ReturnStructure.Insert("PayerSurname",               "lastName");
	ReturnStructure.Insert("PayerName",                   "firstName");
	ReturnStructure.Insert("PayerPatronymic",              "middleName");
	ReturnStructure.Insert("PayerAddress",                 "payerAddress");
	ReturnStructure.Insert("BudgetRecipientAccount",  "personalAccount");
	ReturnStructure.Insert("PaymentDocumentIndex",        "docIdx");
	ReturnStructure.Insert("INILA",                            "pensAcc");
	ReturnStructure.Insert("ContractNo",                    "contract");
	ReturnStructure.Insert("PayerAccountNumber",    "persAcc");
	ReturnStructure.Insert("ApartmentNumber",                    "flat");
	ReturnStructure.Insert("PhoneNumber",                    "phone");
	ReturnStructure.Insert("PayerKind",                   "payerIdType");
	ReturnStructure.Insert("PayerNumber",                 "payerIdNum");
	ReturnStructure.Insert("ChildInitials",                       "childFio");
	ReturnStructure.Insert("BirthDate",                     "birthDate");
	ReturnStructure.Insert("PaymentDueDate",                      "paymTerm");
	ReturnStructure.Insert("PaymentPeriod",                     "paymPeriod");
	ReturnStructure.Insert("PaymentKind",                       "category");
	ReturnStructure.Insert("ServiceCode",                        "serviceName");
	ReturnStructure.Insert("MeteringDeviceNumber",                "counterId");
	ReturnStructure.Insert("MeteredValues",            "counterVal");
	ReturnStructure.Insert("NotificationNumber",                   "quittId");
	ReturnStructure.Insert("NotificationDate",                    "quittDate");
	ReturnStructure.Insert("InstitutionNumber",                  "instNum");
	ReturnStructure.Insert("GroupNumber",                      "classNum");
	ReturnStructure.Insert("TeacherInitials",                 "specFio");
	ReturnStructure.Insert("InsuranceAmount",                   "addAmount");
	ReturnStructure.Insert("OrderNumber",               "ruleId");
	ReturnStructure.Insert("EnforcementNumber", "execId");
	ReturnStructure.Insert("PaymentKindCode",                   "regType");
	ReturnStructure.Insert("AccrualIdentifier",          "uin");
	ReturnStructure.Insert("TechnicalCode",                   "TechCode");
	
	Return ReturnStructure;
	
EndFunction

Function ComponentQRCodeGeneration(Cancel)
	
	SystemInfo = New SystemInfo;
	Platform = SystemInfo.PlatformType;
	
	ErrorText = NStr("en = 'Cannot connect an external component to generate QR code.'");
	
	Try
		If AttachAddIn("CommonTemplate.QRCodePrintComponent", "QR") Then
			QRCodeGenerator = New("AddIn.QR.QRCodeExtension");
		Else
			CommonUseClientServer.MessageToUser(ErrorText, , , , Cancel);
		EndIf
	Except
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		CommonUseClientServer.MessageToUser(ErrorText + Chars.LF + DetailErrorDescription, , , , Cancel);
	EndTry;
	
	Return QRCodeGenerator;
	
EndFunction

Procedure AddMandatoryAttributes(DataStructure)
	
	DataStructure.Insert("PayeeText");
	DataStructure.Insert("RecipientAccountNumber");
	DataStructure.Insert("PayeeBankDescription");
	DataStructure.Insert("RecipientBankBIC");
	DataStructure.Insert("PayeeBankAcc");
	
EndProcedure

Procedure AddAdditionalAttributes(DataStructure)
	
	DataStructure.Insert("AmountAsNumber");
	DataStructure.Insert("PaymentDestination");
	DataStructure.Insert("PayeeTIN");
	DataStructure.Insert("PayerTIN");
	DataStructure.Insert("AuthorStatus");
	DataStructure.Insert("PayeeKPP");
	DataStructure.Insert("BKCode");
	DataStructure.Insert("OKTMOCode");
	DataStructure.Insert("BasisIndicator");
	DataStructure.Insert("PeriodIndicator");
	DataStructure.Insert("NumberIndicator");
	DataStructure.Insert("DateIndicator");
	DataStructure.Insert("TypeIndicator");
	
EndProcedure

Procedure AddOtherAdditionalAttributes(DataStructure)
	
	DataStructure.Insert("PayerSurname");
	DataStructure.Insert("PayerName");
	DataStructure.Insert("PayerPatronymic");
	DataStructure.Insert("PayerAddress");
	DataStructure.Insert("BudgetRecipientAccount");
	DataStructure.Insert("PaymentDocumentIndex");
	DataStructure.Insert("INILA");
	DataStructure.Insert("ContractNo");
	DataStructure.Insert("PayerAccountNumber");
	DataStructure.Insert("ApartmentNumber");
	DataStructure.Insert("PhoneNumber");
	DataStructure.Insert("PayerKind");
	DataStructure.Insert("PayerNumber");
	DataStructure.Insert("ChildInitials");
	DataStructure.Insert("BirthDate");
	DataStructure.Insert("PaymentDueDate");
	DataStructure.Insert("PaymentPeriod");
	DataStructure.Insert("PaymentKind");
	DataStructure.Insert("ServiceCode");
	DataStructure.Insert("MeteringDeviceNumber");
	DataStructure.Insert("MeteredValues");
	DataStructure.Insert("NotificationNumber");
	DataStructure.Insert("NotificationDate");
	DataStructure.Insert("InstitutionNumber");
	DataStructure.Insert("GroupNumber");
	DataStructure.Insert("TeacherInitials");
	DataStructure.Insert("InsuranceAmount");
	DataStructure.Insert("OrderNumber");
	DataStructure.Insert("EnforcementNumber");
	DataStructure.Insert("PaymentKindCode");
	DataStructure.Insert("AccrualIdentifier");
	DataStructure.Insert("TechnicalCode");
	
EndProcedure

// Returns true if there is a permission to post at least one document.
Function PostingRightAvailable(DocumentsList) Export
	DocumentTypes = New Array;
	For Each Document IN DocumentsList Do
		DocumentType = TypeOf(Document);
		If DocumentTypes.Find(DocumentType) <> Undefined Then
			Continue;
		Else
			DocumentTypes.Add(DocumentType);
		EndIf;
		If AccessRight("Posting", Metadata.FindByType(DocumentType)) Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

Procedure MessagePrintingFormIsUnavailable(Object)
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en = 'Print %1 is not performed: the selected print form is unavailable.'"),
		Object);
	CommonUseClientServer.MessageToUser(MessageText, Object);
EndProcedure

// Generates a document package to send for printing.
Function DocumentsPackage(DocumentsTable, PrintObjects, PrintInSets, Copies = 1) Export
	
	RepresentableDocumentBatch = New RepresentableDocumentBatch;
	PrintFormsCollection = DocumentsTable.UnloadValues();
	
	If PrintInSets AND PrintObjects.Count() > 0 Then 
		For Each PrintObject IN PrintObjects Do
			AreaName = PrintObject.Presentation;
			For Each PrintForm IN PrintFormsCollection Do
				Area = PrintForm.Areas.Find(AreaName);
				If Area = Undefined Then
					Continue;
				EndIf;
				
				SpreadsheetDocument = PrintForm.GetArea(Area.Top, , Area.Bottom);
				FillPropertyValues(SpreadsheetDocument, PrintForm, "FitToPage,Output,PageHeight,DuplexPrinting,Protection,PrinterName,TemplateLanguageCode,Copies,PrintScale,PageOrientation,TopMargin,LeftMargin,BottomMargin,RightMargin,Collate,HeaderSize,FooterSize,PageSize,PrintAccuracy,BlackAndWhite,PageWidth,PerPage");
				
				RepresentableDocumentBatch.Content.Add().Data = PackageWithOneTableDocument(SpreadsheetDocument);
			EndDo;
		EndDo;
	Else
		For Each PrintForm IN PrintFormsCollection Do
			SpreadsheetDocument = New SpreadsheetDocument;
			SpreadsheetDocument.Put(PrintForm);
			FillPropertyValues(SpreadsheetDocument, PrintForm, "FitToPage,Output,PageHeight,DuplexPrinting,Protection,PrinterName,TemplateLanguageCode,Copies,PrintScale,PageOrientation,TopMargin,LeftMargin,BottomMargin,RightMargin,Collate,HeaderSize,FooterSize,PageSize,PrintAccuracy,BlackAndWhite,PageWidth,PerPage");
			RepresentableDocumentBatch.Content.Add().Data = PackageWithOneTableDocument(SpreadsheetDocument);
		EndDo;
	EndIf;
	
	RepresentableDocumentBatch.Copies = Copies;
	
	Return RepresentableDocumentBatch;
	
EndFunction

// Wraps a tabular document in a package of displayed documents.
Function PackageWithOneTableDocument(SpreadsheetDocument)
	TabularDocumentAddressInTemporaryStorage = PutToTempStorage(SpreadsheetDocument);
	PackageWithOneDocument = New RepresentableDocumentBatch;
	PackageWithOneDocument.Content.Add(TabularDocumentAddressInTemporaryStorage);
	FillPropertyValues(PackageWithOneDocument, SpreadsheetDocument, "Output, DuplexPrinting, PrinterName, Copies, PrintAccuracy");
	If SpreadsheetDocument.Collate <> Undefined Then
		PackageWithOneDocument.Collate = SpreadsheetDocument.Collate;
	EndIf;
	Return PackageWithOneDocument;
EndFunction

// Adds print commands to a list if the print manager has the corresponding procedure.
Function AddCommandsFromPrintManager(PrintManager, PrintCommands)
	AddedPrintCommands = CreateCollectionPrintCommands();
	Try
		PrintManager.AddPrintCommands(AddedPrintCommands);
	Except
		If AddedPrintCommands.Count() > 0 Then
			Raise;
		Else
			Return False;
		EndIf;
	EndTry;
	
	For Each PrintCommand IN AddedPrintCommands Do
		FillPropertyValues(PrintCommands.Add(), PrintCommand);
	EndDo;
	
	Return True;
EndFunction

// Collects a list of print commands from multiple objects.
Procedure FillPrintCommandsForListOfObjects(ObjectList, PrintCommands)
	For Each MetadataObject IN ObjectList Do
		If MetadataObject.DefaultListForm = Undefined Then
			Continue; // Print commands are not provided in the main form of the object list.
		EndIf;
		ListFormName = MetadataObject.DefaultListForm.FullName();
		PrintCommandsForms =PrintManagementReUse.PrintCommandsForms(ListFormName).Copy();
		For Each PrintCommandAdded IN PrintCommandsForms Do
			// Search for similar print command that was previously added.
			FilterStructure = "ID,Handler,StraightToPrinter,SavingFormat";
			If IsBlankString(PrintCommandAdded.Handler) Then
				FilterStructure = FilterStructure + ",PrintManager";
			EndIf;
			Filter = New Structure(FilterStructure);
			FillPropertyValues(Filter, PrintCommandAdded);
			FoundsCommands = PrintCommands.FindRows(Filter);
			If FoundsCommands.Count() > 0 Then
				For Each PrintCommandAvailable IN FoundsCommands Do
					// If the command already exists, then add object types for which it is for.
					ObjectType = Type(StrReplace(MetadataObject.FullName(), ".", "Ref."));
					If PrintCommandAvailable.PrintingObjectsTypes.Find(ObjectType) = Undefined Then
						PrintCommandAvailable.PrintingObjectsTypes.Add(ObjectType);
					EndIf;
					// Clear PrintManager if it differs for the existing command.
					If PrintCommandAvailable.PrintManager <> PrintCommandAdded.PrintManager Then
						PrintCommandAvailable.PrintManager = "";
					EndIf;
				EndDo;
				Continue;
			EndIf;
			
			If PrintCommandAdded.PrintingObjectsTypes.Count() = 0 Then
				PrintCommandAdded.PrintingObjectsTypes.Add(Type(StrReplace(MetadataObject.FullName(), ".", "Ref.")));
			EndIf;
			FillPropertyValues(PrintCommands.Add(), PrintCommandAdded);
		EndDo;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Determines whether it is possible to save a print form for the object.
// Called from common form PrintFormSaving.
//
// Parameters:
//  ObjectReference    - AnyRef - object to which it is required to attach a print form file;
//  AttachingAllowed - Boolean - (returned) shows whether files can be attached to the object.
//
Procedure OnCanAttachFilesToObjectChecking(ObjectReference, AttachingAllowed) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		ModuleAttachedFiles = CommonUse.CommonModule("AttachedFiles");
		AttachingAllowed = ModuleAttachedFiles.CanAttachFilesToObject(ObjectReference);
	EndIf;
	
EndProcedure

// Fills in printing forms list from the external sources.
//
// Parameters:
//  ExternalPrintForms - ValueList:
//                                         Value      - String - print form identifier;
//                                         Presentation - String - print form name.
//  FullMetadataObjectName - String - full metadata object name for which it
//                                        is required to get a list of print forms.
//
Procedure OnReceivingExternalPrintFormsList(ExternalPrintForms, FullMetadataObjectName) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnReceivingExternalPrintFormsList(ExternalPrintForms, FullMetadataObjectName);
	EndIf;
	
EndProcedure

// Returns a reference to external print form object.
//
Procedure OnExternalPrintFormReceiving(ID, FullMetadataObjectName, ExternalPrintFormRef) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonUse.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnExternalPrintFormReceiving(ID, FullMetadataObjectName, ExternalPrintFormRef);
	EndIf;
	
EndProcedure

#EndRegion

#Region HelperProceduresAndFunctions

// Only for internal use.
//
Function UsedCustomLayoutsCount()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UserPrintTemplates.TemplateName
	|FROM
	|	InformationRegister.UserPrintTemplates AS UserPrintTemplates
	|WHERE
	|	UserPrintTemplates.Use = TRUE";
	
	Result = Query.Execute().Unload();
	
	Return Result.Count();
	
EndFunction

#EndRegion
