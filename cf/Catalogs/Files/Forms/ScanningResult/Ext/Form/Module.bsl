&AtClient
Var AscendingNumberOfImage;

&AtClient
Var InsertionPosition;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Items.FileTable.Visible = False;
	Items.FormAcceptAllAsOneFile.Visible = False;
	Items.FormAcceptAllAsSeparateFiles.Visible = False;
	
	If Parameters.Property("FileOwner") Then
		FileOwner = Parameters.FileOwner;
	EndIf;
	
	ClientID = Parameters.ClientID;
	
	If Parameters.Property("DoNotOpenCardAfterCreateFromFile") Then
		DoNotOpenCardAfterCreateFromFile = Parameters.DoNotOpenCardAfterCreateFromFile;
	EndIf;
	
	FileNumber = FileOperationsServiceServerCall.GetNewNumberForScanning(FileOwner);
	FileName = FileOperationsClientServer.ScannedFileName(FileNumber, "");

	FormatOfScannedImage = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/FormatOfScannedImage", 
		ClientID, Enums.ScannedImagesFormats.PNG);
	
	OnePageStorageFormat = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/OnePageStorageFormat", 
		ClientID, Enums.OnePageFilesStorageFormats.PNG);
	
	MultiPageStorageFormat = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/MultiPageStorageFormat", 
		ClientID, Enums.MultiplePageFilesStorageFormats.TIF);
	
	ResolutionEnum = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/Resolution", 
		ClientID);
	
	ChromaticityEnum = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/Chromaticity", 
		ClientID);
	
	RotationEnum = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/Rotation", 
		ClientID);
	
	PaperSizeEnum = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/PaperSize", 
		ClientID);
	
	DoubleSidedScan = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/DoubleSidedScan", 
		ClientID);
	
	UseImageMagickForConvertionToPDF = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/UseImageMagickForConvertionToPDF", 
		ClientID);
	
	JPGQuality = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/JPGQuality", 
		ClientID, 100);
	
	TIFFCompression = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/TIFFCompression", 
		ClientID, Enums.TIFFCompressionOptions.WithoutCompressing);
	
	PathToConversionApplication = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/PathToConversionApplication", 
		ClientID, "convert.exe"); // ImageMagick
	
	ShowScannerDialogImport = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/ShowScannerDialog", 
		ClientID, True);
	
	ShowScannerDialog = ShowScannerDialogImport;
	
	DeviceName = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/DeviceName", 
		ClientID, "");
	
	ScanningDeviceName = DeviceName;
	
	If UseImageMagickForConvertionToPDF Then
		If OnePageStorageFormat = Enums.OnePageFilesStorageFormats.PDF Then
			PictureFormat = String(FormatOfScannedImage);
		Else	
			PictureFormat = String(OnePageStorageFormat);
		EndIf;
	Else	
		PictureFormat = String(FormatOfScannedImage);
	EndIf;
	
	JPGFormat = Enums.ScannedImagesFormats.JPG;
	TIFFormat = Enums.ScannedImagesFormats.TIF;
	
	ConvertEnumsToParametersAndGetPresentation();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not ChecksAtOpeningCompleted Then
		Cancel = True;
		AttachIdleHandler("BeforeOpen", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.Files.Form.ScanningSetupForSession") Then
		
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		
		ResolutionEnum   = ValueSelected.Resolution;
		ChromaticityEnum    = ValueSelected.Chromaticity;
		RotationEnum      = ValueSelected.Rotation;
		PaperSizeEnum = ValueSelected.PaperSize;
		DoubleSidedScan = ValueSelected.DoubleSidedScan;
		
		UseImageMagickForConvertionToPDF = ValueSelected.UseImageMagickForConvertionToPDF;
		
		ShowScannerDialog         = ValueSelected.ShowScannerDialog;
		FormatOfScannedImage = ValueSelected.FormatOfScannedImage;
		JPGQuality                     = ValueSelected.JPGQuality;
		TIFFCompression                      = ValueSelected.TIFFCompression;
		OnePageStorageFormat    = ValueSelected.OnePageStorageFormat;
		MultiPageStorageFormat   = ValueSelected.MultiPageStorageFormat;
		
		ConvertEnumsToParametersAndGetPresentation();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	DeleteTemporaryFiles(FileTable);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersFileTable

&AtClient
Procedure FileTableOnActivateRow(Item)
#If Not WebClient Then
	CurrentLineNumber = Items.FileTable.CurrentRow;
	TableRow = Items.FileTable.RowData(CurrentLineNumber);
	
	If PathToSelectedFile <> TableRow.PathToFile Then
		
		PathToSelectedFile = TableRow.PathToFile;
		
		If IsBlankString(TableRow.PictureURL) Then
			BinaryData = New BinaryData(PathToSelectedFile);
			TableRow.PictureURL = PutToTempStorage(BinaryData, UUID);
		EndIf;	
		
		PictureURL = TableRow.PictureURL;
		
	EndIf;	
	
#EndIf	
EndProcedure

&AtClient
Procedure FileTableBeforeDeletion(Item, Cancel)
	
	If FileTable.Count() < 2 Then
		Cancel = True;
		Return;
	EndIf;
	
	CurrentLineNumber = Items.FileTable.CurrentRow;
	TableRow = Items.FileTable.RowData(CurrentLineNumber);
	DeleteFiles(TableRow.PathToFile);
	
	If FileTable.Count() = 2 Then
		Items.FilesTableContextMenuDelete.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Cancel(Command)
	DeleteTemporaryFiles(FileTable);
	Close();
EndProcedure

// Button "Rescan" replaces the selected image (or the only one image) (or adds new images to the end if no images are selected) with a new image(s).
&AtClient
Procedure Rescan(Command)
	
	If FileTable.Count() = 1 Then
		DeleteTemporaryFiles(FileTable);
	ElsIf FileTable.Count() > 1 Then
		
		CurrentLineNumber = Items.FileTable.CurrentRow;
		TableRow = Items.FileTable.RowData(CurrentLineNumber);
		InsertionPosition = FileTable.IndexOf(TableRow);
		DeleteFiles(TableRow.PathToFile);
		FileTable.Delete(TableRow);
		
	EndIf;
	
	If PictureURL <> "" Then
		DeleteFromTempStorage(PictureURL);
	EndIf;	
	PictureURL = "";
	PathToSelectedFile = "";
	
	ShowDialog = ShowScannerDialog;
	SelectedDevice = ScanningDeviceName;
	DeflateParameter = ?(Upper(PictureFormat) = "JPG", JPGQuality, TIFFDeflationNumber);
	
	ApplicationParameters["StandardSubsystems.TwainAddIn"].StartScanning(
		ShowDialog, SelectedDevice, PictureFormat, 
		Resolution, Chromaticity, Rotation, PaperSize, 
		DeflateParameter,
		DoubleSidedScan);
		
EndProcedure

&AtClient
Procedure AcceptAllAsSeparateFiles(Command)
	
	FileArrayCopy = New Array;
	For Each String IN FileTable Do
		FileArrayCopy.Add(New Structure("PathToFile", String.PathToFile));
	EndDo;
	
	FileTable.Clear(); // Not to delete files in OnClose.
	
	Close();
	
	ResultExtension = String(OnePageStorageFormat);
	ResultExtension = Lower(ResultExtension); 
	
	AddingParameters = New Structure;
	AddingParameters.Insert("FileOwner", FileOwner);
	AddingParameters.Insert("UUID", UUID);
	AddingParameters.Insert("FullFileName", "");
	AddingParameters.Insert("CreatedFileName", "");
	
	FullAllTextErrors = "";
	ErrorsCount = 0;
	
	// Here we work with all images, each image is accepted as a separate file.
	For Each String IN FileArrayCopy Do
		
		PathToFileLocal = String.PathToFile;
		
		ResultFile = "";
		If ResultExtension = "pdf" Then
			
			#If Not WebClient Then
				ResultFile = GetTempFileName("pdf");
			#EndIf
			
			AllPathsString = PathToFileLocal;
			ApplicationParameters["StandardSubsystems.TwainAddIn"].MergeIntoMultipageFile(
				AllPathsString, ResultFile, PathToConversionApplication);
			
			ObjectResultFile = New File(ResultFile);
			If Not ObjectResultFile.Exist() Then
				ErrorText = MessageTextErrorsInPDFConversions(ResultFile);
				If FullAllTextErrors <> "" Then
					FullAllTextErrors = FullAllTextErrors + Chars.LF + Chars.LF + "---" + Chars.LF + Chars.LF;
				EndIf;
				FullAllTextErrors = FullAllTextErrors + ErrorText;
				ErrorsCount = ErrorsCount + 1;
				ResultFile = "";
			EndIf;
			
			PathToFileLocal = ResultFile;
			
		EndIf;
		
		If Not IsBlankString(PathToFileLocal) Then
			AddingParameters.FullFileName = PathToFileLocal;
			AddingParameters.CreatedFileName = FileName;
			Result = FileOperationsServiceClient.AddFromFileSystemWithExtensionSynchronously(AddingParameters);
			If Not Result.FileAdded Then
				If ValueIsFilled(Result.ErrorText) Then
					ShowMessageBox(, Result.ErrorText);
					Return;
				EndIf;
			EndIf;
		EndIf;
		
		If Not IsBlankString(ResultFile) Then
			DeleteFiles(ResultFile);
		EndIf;
		
		FileNumber = FileNumber + 1;
		FileName = FileOperationsClientServer.ScannedFileName(FileNumber, "");
		
	EndDo;
	
	FileOperationsServiceServerCall.PlaceMaxNumberForScanning(
		FileOwner, FileNumber - 1);
	
	DeleteTemporaryFiles(FileArrayCopy);
	
	If ErrorsCount > 0 Then
		Result = StandardSubsystemsClientServer.NewExecutionResult();
		Result.OutputWarning.Use = True;
		If ErrorsCount = 1 Then
			Result.OutputWarning.Text = FullAllTextErrors;
		Else
			ShortAllTextErrors = StrReplace(NStr("en='During execution, errors occurred (%1).';ru='При выполнении возникли ошибки (%1).'"), "%1", String(ErrorsCount));
			Result.OutputWarning.Text = ShortAllTextErrors;
			Result.OutputWarning.ErrorsText = FullAllTextErrors;
		EndIf;
		StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	EndIf;
	
EndProcedure

&AtClient
Procedure Accept(Command)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("FileArrayCopy", New Array);
	ExecuteParameters.Insert("ResultFile", "");
	
	For Each String IN FileTable Do
		ExecuteParameters.FileArrayCopy.Add(New Structure("PathToFile", String.PathToFile));
	EndDo;
	
	// Here we work with one file.
	TableRow = FileTable.Get(0);
	PathToFileLocal = TableRow.PathToFile;
	
	FileTable.Clear(); // Not to delete files in OnClose.
	
	Close();
	
	ResultExtension = String(OnePageStorageFormat);
	ResultExtension = Lower(ResultExtension); 
	
	If ResultExtension = "pdf" Then
		
		#If Not WebClient Then
			ExecuteParameters.ResultFile = GetTempFileName("pdf");
		#EndIf
		
		AllPathsString = PathToFileLocal;
		ApplicationParameters["StandardSubsystems.TwainAddIn"].MergeIntoMultipageFile(
			AllPathsString, ExecuteParameters.ResultFile, PathToConversionApplication);
		
		ObjectResultFile = New File(ExecuteParameters.ResultFile);
		If Not ObjectResultFile.Exist() Then
			MessageText = MessageTextErrorsInPDFConversions(ExecuteParameters.ResultFile);
			ShowMessageBox(, MessageText);
			DeleteFiles(PathToFileLocal);
			AcceptEnd(-1, ExecuteParameters);
			Return;
		EndIf;
		
		DeleteFiles(PathToFileLocal);
		PathToFileLocal = ExecuteParameters.ResultFile;
		
	EndIf;
	
	If Not IsBlankString(PathToFileLocal) Then
		Handler = New NotifyDescription("AcceptEnd", ThisObject, ExecuteParameters);
		
		AddingParameters = New Structure;
		AddingParameters.Insert("ResultHandler", Handler);
		AddingParameters.Insert("FullFileName", PathToFileLocal);
		AddingParameters.Insert("FileOwner", FileOwner);
		AddingParameters.Insert("OwnerForm", ThisObject);
		AddingParameters.Insert("CreatedFileName", FileName);
		AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", DoNotOpenCardAfterCreateFromFile);
		
		FileOperationsServiceClient.AddFromFileSystemWithExtension(AddingParameters);
		
		Return;
	EndIf;
	
	AcceptEnd(-1, ExecuteParameters);
EndProcedure

&AtClient
Procedure Setting(Command)
	
	DoubleSidedScanNumber = FileOperationsServiceClient.GetSetting(
		ScanningDeviceName, "DUPLEX");
	
	EnabledDoubleSidedScan = (DoubleSidedScanNumber <> -1);
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowScannerDialog",  ShowScannerDialog);
	FormParameters.Insert("Resolution",               ResolutionEnum);
	FormParameters.Insert("Chromaticity",                ChromaticityEnum);
	FormParameters.Insert("Rotation",                  RotationEnum);
	FormParameters.Insert("PaperSize",             PaperSizeEnum);
	FormParameters.Insert("DoubleSidedScan", DoubleSidedScan);
	
	FormParameters.Insert(
		"UseImageMagickForConvertionToPDF", UseImageMagickForConvertionToPDF);
	
	FormParameters.Insert("RotationAccessible",       RotationAccessible);
	FormParameters.Insert("IsPaperSizeAccessible",  IsPaperSizeAccessible);
	
	FormParameters.Insert("EnabledDoubleSidedScan", EnabledDoubleSidedScan);
	FormParameters.Insert("FormatOfScannedImage",     FormatOfScannedImage);
	FormParameters.Insert("JPGQuality",                         JPGQuality);
	FormParameters.Insert("TIFFCompression",                          TIFFCompression);
	FormParameters.Insert("OnePageStorageFormat",        OnePageStorageFormat);
	FormParameters.Insert("MultiPageStorageFormat",       MultiPageStorageFormat);
	
	OpenForm("Catalog.Files.Form.ScanningSetupForSession", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure AcceptAllAsOneFile(Command)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("FileArrayCopy", New Array);
	ExecuteParameters.Insert("ResultFile", "");
	
	For Each String IN FileTable Do
		ExecuteParameters.FileArrayCopy.Add(New Structure("PathToFile", String.PathToFile));
	EndDo;
	
	FileTable.Clear(); // Not to delete files in OnClose.
	
	Close();
	
	// Here we work with all images - combine them into one multipage file.
	AllPathsString = "";
	For Each String IN ExecuteParameters.FileArrayCopy Do
		AllPathsString = AllPathsString + "*";
		AllPathsString = AllPathsString + String.PathToFile;
	EndDo;
	
	#If Not WebClient Then
		ResultExtension = String(MultiPageStorageFormat);
		ResultExtension = Lower(ResultExtension); 
		ExecuteParameters.ResultFile = GetTempFileName(ResultExtension);
	#EndIf
	ApplicationParameters["StandardSubsystems.TwainAddIn"].MergeIntoMultipageFile(
		AllPathsString, ExecuteParameters.ResultFile, PathToConversionApplication);
	
	ObjectResultFile = New File(ExecuteParameters.ResultFile);
	If Not ObjectResultFile.Exist() Then
		MessageText = MessageTextErrorsInPDFConversions(ExecuteParameters.ResultFile);
		ExecuteParameters.ResultFile = "";
		Handler = New NotifyDescription("AcceptAllAsOneFileEnd", ThisObject, ExecuteParameters);
		ShowMessageBox(Handler, MessageText);
		Return;
	EndIf;
	
	If Not IsBlankString(ExecuteParameters.ResultFile) Then
		Handler = New NotifyDescription("AcceptAllAsOneFileEnd", ThisObject, ExecuteParameters);
		
		AddingParameters = New Structure;
		AddingParameters.Insert("ResultHandler", Handler);
		AddingParameters.Insert("FileOwner", FileOwner);
		AddingParameters.Insert("OwnerForm", ThisObject);
		AddingParameters.Insert("FullFileName", ExecuteParameters.ResultFile);
		AddingParameters.Insert("CreatedFileName", FileName);
		AddingParameters.Insert("DoNotOpenCardAfterCreateFromFile", DoNotOpenCardAfterCreateFromFile);
		
		FileOperationsServiceClient.AddFromFileSystemWithExtension(AddingParameters);
		
		Return;
	EndIf;
	
	AcceptAllAsOneFileEnd(-1, ExecuteParameters);
EndProcedure

&AtClient
Procedure ScanStill(Command)
	
	ShowDialog = ShowScannerDialog;
	SelectedDevice = ScanningDeviceName;
	PathToConversionApplication = "convert.exe";
	DeflateParameter = ?(Upper(PictureFormat) = "JPG", JPGQuality, TIFFDeflationNumber);
	
	InsertionPosition = Undefined;
	
	ApplicationParameters["StandardSubsystems.TwainAddIn"].StartScanning(
		ShowDialog, SelectedDevice, PictureFormat, 
		Resolution, Chromaticity, Rotation, PaperSize, 
		DeflateParameter,
		DoubleSidedScan);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure BeforeOpen()
	// Initial machine initialization (call from OnOpen()).
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentStep", 1);
	OpenParameters.Insert("ShowDialog", Undefined);
	OpenParameters.Insert("SelectedDevice", Undefined);
	BeforeOpenAutomatic(Undefined, OpenParameters);
EndProcedure

&AtClient
Procedure BeforeOpenAutomatic(Result, OpenParameters) Export
	// Secondary initializing machine challenge of dialog open automaton).
	If OpenParameters.CurrentStep = 2 Then
		If TypeOf(Result) = Type("String") AND Not IsBlankString(Result) Then
			OpenParameters.SelectedDevice = Result;
		EndIf;
		OpenParameters.CurrentStep = 3;
	EndIf;
	
	If OpenParameters.CurrentStep = 1 Then
		If Not FileOperationsServiceClient.InitializeComponent() Then
			Return;
		EndIf;
		
		// It is called here as call ApplicationParameters ["StandardSubsystems.TwainAddIn"].DevicesExist()
		// takes too much time (longer than RefreshReusableValues()).
		If Not FileOperationsServiceClient.CommandScanAvailable() Then
			RefreshReusableValues();
			Return;
		EndIf;
		
		OpenParameters.CurrentStep = 2;
	EndIf;
	
	If OpenParameters.CurrentStep = 2 Then
		OpenParameters.ShowDialog = ShowScannerDialog;
		OpenParameters.SelectedDevice = ScanningDeviceName;
		
		If OpenParameters.SelectedDevice = "" Then
			Handler = New NotifyDescription("BeforeOpenAutomatic", ThisObject, OpenParameters);
			OpenForm("Catalog.Files.Form.ScanningDeviceSelection", , ThisObject, , , , Handler, FormWindowOpeningMode.LockWholeInterface);
			Return;
		EndIf;
		
		OpenParameters.CurrentStep = 3;
	EndIf;
	
	If OpenParameters.CurrentStep = 3 Then
		If OpenParameters.SelectedDevice = "" Then 
			Return; // Do not open the form.
		EndIf;
		
		If Resolution = -1 OR Chromaticity = -1 OR Rotation = -1 OR PaperSize = -1 Then
			
			Resolution = FileOperationsServiceClient.GetSetting(
				OpenParameters.SelectedDevice,
				"XRESOLUTION");
			
			Chromaticity = FileOperationsServiceClient.GetSetting(
				OpenParameters.SelectedDevice,
				"PIXELTYPE");
			
			Rotation = FileOperationsServiceClient.GetSetting(
				OpenParameters.SelectedDevice,
				"ROTATION");
			
			PaperSize = FileOperationsServiceClient.GetSetting(
				OpenParameters.SelectedDevice,
				"SUPPORTEDSIZES");
			
			DoubleSidedScanNumber = FileOperationsServiceClient.GetSetting(
				OpenParameters.SelectedDevice,
				"DUPLEX");
			
			RotationAccessible = (Rotation <> -1);
			IsPaperSizeAccessible = (PaperSize <> -1);
			EnabledDoubleSidedScan = (DoubleSidedScanNumber <> -1);
			
			SystemInfo = New SystemInfo();
			ClientID = SystemInfo.ClientID;
			
			SaveScannerParameters(Resolution, Chromaticity, ClientID);
		Else
			
			RotationAccessible = Not RotationEnum.IsEmpty();
			IsPaperSizeAccessible = Not PaperSizeEnum.IsEmpty();
			EnabledDoubleSidedScan = True;
			
		EndIf;
		
		PictureFileName = "";
		Items.Accept.Enabled = False;
		
		DeflateParameter = ?(Upper(PictureFormat) = "JPG", JPGQuality, TIFFDeflationNumber);
		
		If Not IsOpen() Then
			ChecksAtOpeningCompleted = True;
			Open();
			ChecksAtOpeningCompleted = False;
		EndIf;
		
		ApplicationParameters["StandardSubsystems.TwainAddIn"].StartScanning(
			OpenParameters.ShowDialog,
			OpenParameters.SelectedDevice,
			PictureFormat,
			Resolution,
			Chromaticity,
			Rotation,
			PaperSize,
			DeflateParameter,
			DoubleSidedScan);
	EndIf;
	
EndProcedure

&AtClient
Procedure AcceptEnd(Result, ExecuteParameters) Export
	DeleteTemporaryFiles(ExecuteParameters.FileArrayCopy);
	If Not IsBlankString(ExecuteParameters.ResultFile) Then
		DeleteFiles(ExecuteParameters.ResultFile);
	EndIf;
EndProcedure

&AtClient
Procedure AcceptAllAsOneFileEnd(Result, ExecuteParameters) Export
	DeleteTemporaryFiles(ExecuteParameters.FileArrayCopy);
	DeleteFiles(ExecuteParameters.ResultFile);
EndProcedure

&AtServer
Procedure ConvertEnumsToParametersAndGetPresentation()
		
	Resolution = -1;
	If ResolutionEnum = Enums.ScannedImageResolutions.dpi200 Then
		Resolution = 200; 
	ElsIf ResolutionEnum = Enums.ScannedImageResolutions.dpi300 Then
		Resolution = 300;
	ElsIf ResolutionEnum = Enums.ScannedImageResolutions.dpi600 Then
		Resolution = 600;
	ElsIf ResolutionEnum = Enums.ScannedImageResolutions.dpi1200 Then
		Resolution = 1200;
	EndIf;
	
	Chromaticity = -1;
	If ChromaticityEnum = Enums.ImageChromaticities.Monochrome Then
		Chromaticity = 0;
	ElsIf ChromaticityEnum = Enums.ImageChromaticities.GrayGradations Then
		Chromaticity = 1;
	ElsIf ChromaticityEnum = Enums.ImageChromaticities.Color Then
		Chromaticity = 2;
	EndIf;
	
	Rotation = 0;
	If RotationEnum = Enums.ImageRotationMethods.NoRotation Then
		Rotation = 0;
	ElsIf RotationEnum = Enums.ImageRotationMethods.ToTheRightAt90 Then
		Rotation = 90;
	ElsIf RotationEnum = Enums.ImageRotationMethods.ToTheRightAt180 Then
		Rotation = 180;
	ElsIf RotationEnum = Enums.ImageRotationMethods.ToTheLeftAt90 Then
		Rotation = 270;
	EndIf;
	
	PaperSize = 0;
	If PaperSizeEnum = Enums.PaperSizes.NotDefined Then
		PaperSize = 0;
	ElsIf PaperSizeEnum = Enums.PaperSizes.A3 Then
		PaperSize = 11;
	ElsIf PaperSizeEnum = Enums.PaperSizes.A4 Then
		PaperSize = 1;
	ElsIf PaperSizeEnum = Enums.PaperSizes.A5 Then
		PaperSize = 5;
	ElsIf PaperSizeEnum = Enums.PaperSizes.B4 Then
		PaperSize = 6;
	ElsIf PaperSizeEnum = Enums.PaperSizes.B5 Then
		PaperSize = 2;
	ElsIf PaperSizeEnum = Enums.PaperSizes.B6 Then
		PaperSize = 7;
	ElsIf PaperSizeEnum = Enums.PaperSizes.C4 Then
		PaperSize = 14;
	ElsIf PaperSizeEnum = Enums.PaperSizes.C5 Then
		PaperSize = 15;
	ElsIf PaperSizeEnum = Enums.PaperSizes.C6 Then
		PaperSize = 16;
	ElsIf PaperSizeEnum = Enums.PaperSizes.USLetter Then
		PaperSize = 3;
	ElsIf PaperSizeEnum = Enums.PaperSizes.USLegal Then
		PaperSize = 4;
	ElsIf PaperSizeEnum = Enums.PaperSizes.USExecutive Then
		PaperSize = 10;
	EndIf;
	
	TIFFDeflationNumber = 6; // WithoutCompressing
	If TIFFCompression = Enums.TIFFCompressionOptions.LZW Then
		TIFFDeflationNumber = 2;
	ElsIf TIFFCompression = Enums.TIFFCompressionOptions.RLE Then
		TIFFDeflationNumber = 5;
	ElsIf TIFFCompression = Enums.TIFFCompressionOptions.WithoutCompressing Then
		TIFFDeflationNumber = 6;
	ElsIf TIFFCompression = Enums.TIFFCompressionOptions.CCITT3 Then
		TIFFDeflationNumber = 3;
	ElsIf TIFFCompression = Enums.TIFFCompressionOptions.CCITT4 Then
		TIFFDeflationNumber = 4;
		
	EndIf;
	
	Presentation = "";
	// Information label of a kind:
	// "Storage format: PDF. Scan format: JPG. Quality: 75. Multi-page storage format: PDF. Resolution:
	// 200. Color";
	
	If UseImageMagickForConvertionToPDF Then
		If OnePageStorageFormat = Enums.OnePageFilesStorageFormats.PDF Then
			PictureFormat = String(FormatOfScannedImage);
			
			Presentation = Presentation + NStr("en='Scanning format:';ru='Формат хранения:'") + " ";
			Presentation = Presentation + "PDF";
			Presentation = Presentation + ". ";
			Presentation = Presentation + NStr("en='Scanning format:';ru='Формат хранения:'") + " ";
			Presentation = Presentation + PictureFormat;
			Presentation = Presentation + ". ";
		Else	
			PictureFormat = String(OnePageStorageFormat);
			Presentation = Presentation + NStr("en='Scanning format:';ru='Формат хранения:'") + " ";
			Presentation = Presentation + PictureFormat;
			Presentation = Presentation + ". ";
		EndIf;
	Else	
		PictureFormat = String(FormatOfScannedImage);
		Presentation = Presentation + NStr("en='Scanning format:';ru='Формат хранения:'") + " ";
		Presentation = Presentation + PictureFormat;
		Presentation = Presentation + ". ";
	EndIf;

	If Upper(PictureFormat) = "JPG" Then
		Presentation = Presentation +  NStr("en='Quality:';ru='Качество:'") + " " + String(JPGQuality) + ". ";
	EndIf;	
	
	If Upper(PictureFormat) = "TIF" Then
		Presentation = Presentation +  NStr("en='Deflate:';ru='дефлятируем:'") + " " + String(TIFFCompression) + ". ";
	EndIf;
	
	Presentation = Presentation + NStr("en='Multipage storage format:';ru='Формат хранения многостраничный:'") + " ";
	Presentation = Presentation + String(MultiPageStorageFormat);
	Presentation = Presentation + ". ";
	
	Presentation = Presentation + StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Resolution: %1 dpi. %2.';ru='Разрешение: %1 dpi. %2.'") + " ",
		String(Resolution), String(ChromaticityEnum));
	
	If Not RotationEnum.IsEmpty() Then
		Presentation = Presentation +  NStr("en='Rotation:';ru='Поворот:'")+ " " + String(RotationEnum) + ". ";
	EndIf;	
	
	If Not PaperSizeEnum.IsEmpty() Then
		Presentation = Presentation +  NStr("en='Paper size:';ru='Размер бумаги:'") + " " + String(PaperSizeEnum) + ". ";
	EndIf;	
	
	If DoubleSidedScan = True Then
		Presentation = Presentation +  NStr("en='Double sided scanning';ru='Двустороннее сканирование'") + ". ";
	EndIf;	
	
	SettingsText = Presentation;
	
EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
#If Not WebClient Then
		
	If Source = "TWAIN" AND Event = "ImageAcquired" Then
		
		PictureFileName = Data;
		Items.Accept.Enabled = True;
		
		LineCountBeforeAdding = FileTable.Count();
		
		TableRow = Undefined;
		
		If InsertionPosition = Undefined Then
			TableRow = FileTable.Add();
		Else	
			TableRow = FileTable.Insert(InsertionPosition);
			InsertionPosition = InsertionPosition + 1;
		EndIf;
		
		TableRow.PathToFile = PictureFileName;
		
		If AscendingNumberOfImage = Undefined Then
			AscendingNumberOfImage = 1;
		EndIf;	
			
		TableRow.Presentation = "Picture" + String(AscendingNumberOfImage);
		AscendingNumberOfImage = AscendingNumberOfImage + 1;
		
		If LineCountBeforeAdding = 0 Then
			PathToSelectedFile = TableRow.PathToFile;
			BinaryData = New BinaryData(PathToSelectedFile);
			PictureURL = PutToTempStorage(BinaryData, UUID);
			TableRow.PictureURL = PictureURL;
		EndIf;
		
		If FileTable.Count() > 1 AND Items.FileTable.Visible = False Then
			Items.FileTable.Visible = True;
			Items.FormAcceptAllAsOneFile.Visible = True;
			Items.FormAcceptAllAsSeparateFiles.Visible = True;
			Items.Accept.Visible = False;
		EndIf;	
		
		If FileTable.Count() > 1 Then
			Items.FilesTableContextMenuDelete.Enabled = True;
		EndIf;	
		
	ElsIf Source = "TWAIN" AND Event = "EndBatch" Then
		
		If FileTable.Count() <> 0 Then
			RowID = FileTable[FileTable.Count() - 1].GetID();
			Items.FileTable.CurrentRow = RowID;
		EndIf;	
		
	ElsIf Source = "TWAIN" AND Event = "UserPressedCancel" Then	
		Close();
	EndIf;	
	
#EndIf

EndProcedure

&AtClient
Procedure DeleteTemporaryFiles(FileValueTable)
	
	For Each String IN FileValueTable Do
		DeleteFiles(String.PathToFile);
	EndDo;	
	
	FileValueTable.Clear();
	
EndProcedure

&AtClient
Function MessageTextErrorsInPDFConversions(ResultFile)
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='File ""%1"" is not found.
		|Check whether application ImageMagick
		|is installed and a correct path to
		|PDF conversion application is specified in the scan settings form.';ru='Не найден файл ""%1"".
		|Проверьте, что
		|установлена программа ImageMagick и указан правильный
		|путь к программе преобразования в PDF в форме настроек сканирования.'"),
		ResultFile);
		
	Return MessageText;
	
EndFunction

&AtServerNoContext
Procedure SaveScannerParameters(PermissionNumber, ChromaticityNumber, ClientID) 
	
	Result = FileOperationsService.ScannerParametersInEnumerations(PermissionNumber, ChromaticityNumber, 0, 0);
	CommonUse.CommonSettingsStorageSave("ScanningSettings/Resolution", ClientID, Result.Resolution);
	CommonUse.CommonSettingsStorageSave("ScanningSettings/Chromaticity", ClientID, Result.Chromaticity);
	
EndProcedure

#EndRegion














