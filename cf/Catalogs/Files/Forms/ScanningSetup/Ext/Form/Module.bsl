
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.AddInInstalled Then
		Items.SetScanningComponent.Visible = False;
	EndIf;	
	
	ClientID = Parameters.ClientID;
	
	ShowScannerDialog = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/ShowScannerDialog", 
		ClientID, True);
	
	DeviceName = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/DeviceName", 
		ClientID, "");
	
	FormatOfScannedImage = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/FormatOfScannedImage", 
		ClientID, Enums.ScannedImagesFormats.PNG);
	
	OnePageStorageFormat = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/OnePageStorageFormat", 
		ClientID, Enums.OnePageFilesStorageFormats.PNG);
	
	MultiPageStorageFormat = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/MultiPageStorageFormat", 
		ClientID, Enums.MultiplePageFilesStorageFormats.TIF);
	
	Resolution = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/Resolution", 
		ClientID);
	
	Chromaticity = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/Chromaticity", 
		ClientID);
	
	Rotation = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/Rotation", 
		ClientID);
	
	PaperSize = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/PaperSize", 
		ClientID);
	
	DoubleSidedScan = CommonUse.CommonSettingsStorageImport(
		"ScanningSettings/DoubleSidedScan", 
		ClientID);
	
	UseImageMagickForConvertionToPDF =  CommonUse.CommonSettingsStorageImport(
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
	
	JPGFormat = Enums.ScannedImagesFormats.JPG;
	TIFFormat = Enums.ScannedImagesFormats.TIF;
	
	MultiplePagesTIFFormat = Enums.MultiplePageFilesStorageFormats.TIF;
	OnePagePDFFormat = Enums.OnePageFilesStorageFormats.PDF;
	OnePageJPGFormat = Enums.OnePageFilesStorageFormats.JPG;
	OnePageTIFFormat = Enums.OnePageFilesStorageFormats.TIF;
	OnePagePNGFormat = Enums.OnePageFilesStorageFormats.PNG;
	
	If Not UseImageMagickForConvertionToPDF Then
		MultiPageStorageFormat = MultiplePagesTIFFormat;
	EndIf;	
	
	Items.StorageFormatGroup.Visible = UseImageMagickForConvertionToPDF;
	
	If UseImageMagickForConvertionToPDF Then
		If OnePageStorageFormat = OnePagePDFFormat Then
			Items.JPGQuality.Visible = (FormatOfScannedImage = JPGFormat);
			Items.TIFFCompression.Visible = (FormatOfScannedImage = TIFFormat);
		Else	
			Items.JPGQuality.Visible = (OnePageStorageFormat = OnePageJPGFormat);
			Items.TIFFCompression.Visible = (OnePageStorageFormat = OnePageTIFFormat);
		EndIf;
	Else	
		Items.JPGQuality.Visible = (FormatOfScannedImage = JPGFormat);
		Items.TIFFCompression.Visible = (FormatOfScannedImage = TIFFormat);
	EndIf;
	
	DecorationsVisible = (UseImageMagickForConvertionToPDF AND (OnePageStorageFormat = OnePagePDFFormat));
	Items.DecorationOnePageStorageFormat.Visible = DecorationsVisible;
	Items.DecorationFormatOfScannedImage.Visible = DecorationsVisible;
	
	ScanningFormatVisible = (UseImageMagickForConvertionToPDF AND (OnePageStorageFormat = OnePagePDFFormat)) OR (NOT UseImageMagickForConvertionToPDF);
	Items.ScanningFormatGroup.Visible = ScanningFormatVisible;
	
	Items.PathToConversionApplication.Enabled = UseImageMagickForConvertionToPDF;
	
	Items.MultiPageStorageFormat.Enabled = UseImageMagickForConvertionToPDF;
	
	OnePageStorageFormatPrevious = OnePageStorageFormat;
	
	If Not UseImageMagickForConvertionToPDF Then
		Items.FormatOfScannedImage.Title = NStr("en='Format';ru='Формат'");
	Else
		Items.FormatOfScannedImage.Title = NStr("en='Type';ru='Тип'");
	EndIf;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject,
		"GroupStorageFormatSingleRow,GroupMultiPageStorageFormat,GroupScanningParameters");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	RefreshStatus1();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DeviceNameOnChange(Item)
	ReadScannerSettings();
EndProcedure

&AtClient
Procedure DeviceNameChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If DeviceName = ValueSelected Then // Nothing changed - do nothing.
		StandardProcessing = False;
	EndIf;	
EndProcedure

&AtClient
Procedure FormatOfScannedImageOnChange(Item)
	
	If UseImageMagickForConvertionToPDF Then
		If OnePageStorageFormat = OnePagePDFFormat Then
			Items.JPGQuality.Visible = (FormatOfScannedImage = JPGFormat);
			Items.TIFFCompression.Visible = (FormatOfScannedImage = TIFFormat);
		Else	
			Items.JPGQuality.Visible = (OnePageStorageFormat = OnePageJPGFormat);
			Items.TIFFCompression.Visible = (OnePageStorageFormat = OnePageTIFFormat);
		EndIf;
	Else	
		Items.JPGQuality.Visible = (FormatOfScannedImage = JPGFormat);
		Items.TIFFCompression.Visible = (FormatOfScannedImage = TIFFormat);
	EndIf;
	
EndProcedure

&AtClient
Procedure PathToConversionApplicationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		Return;
	EndIf;
		
	FileOpeningDialog = New FileDialog(FileDialogMode.Open);
	FileOpeningDialog.FullFileName = PathToConversionApplication;
	Filter = NStr("en='Executable files(*.exe)|*.exe';ru='Исполняемые файлы(*.exe)|*.exe'");
	FileOpeningDialog.Filter = Filter;
	FileOpeningDialog.Multiselect = False;
	FileOpeningDialog.Title = NStr("en='Select file for PDF conversion';ru='Выберите файл для преобразования в PDF'");
	If FileOpeningDialog.Choose() Then
		PathToConversionApplication = FileOpeningDialog.FullFileName;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnePageStorageFormatOnChange(Item)
	
	WorkChangesOnePageStorageFormat();
	
EndProcedure

&AtClient
Procedure UseImageMagickForConvertionToPDFOnChange(Item)
	
	WorkChangesUseImageMagick();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	StructuresArray = New Array;
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	StructuresArray.Add (GenerateSetting("ShowScannerDialog", ShowScannerDialog, ClientID));
	StructuresArray.Add (GenerateSetting("DeviceName", DeviceName, ClientID));
	
	StructuresArray.Add (GenerateSetting("FormatOfScannedImage", FormatOfScannedImage, ClientID));
	StructuresArray.Add (GenerateSetting("OnePageStorageFormat", OnePageStorageFormat, ClientID));
	StructuresArray.Add (GenerateSetting("MultiPageStorageFormat", MultiPageStorageFormat, ClientID));
	StructuresArray.Add (GenerateSetting("Resolution", Resolution, ClientID));
	StructuresArray.Add (GenerateSetting("Chromaticity", Chromaticity, ClientID));
	StructuresArray.Add (GenerateSetting("Rotation", Rotation, ClientID));
	StructuresArray.Add (GenerateSetting("PaperSize", PaperSize, ClientID));
	StructuresArray.Add (GenerateSetting("DoubleSidedScan", DoubleSidedScan, ClientID));
	StructuresArray.Add (GenerateSetting("UseImageMagickForConvertionToPDF", UseImageMagickForConvertionToPDF, ClientID));
	StructuresArray.Add (GenerateSetting("JPGQuality", JPGQuality, ClientID));
	StructuresArray.Add (GenerateSetting("TIFFCompression", TIFFCompression, ClientID));
	StructuresArray.Add (GenerateSetting("PathToConversionApplication", PathToConversionApplication, ClientID));
	
	CommonUseServerCall.CommonSettingsStorageSaveArrayAndUpdateReUseValues(StructuresArray);
	Close();
	
EndProcedure

&AtClient
Procedure SetScanningComponent(Command)
	Handler = New NotifyDescription("SetScanningComponentEnd", ThisObject);
	FileOperationsServiceClient.SetComponent(Handler);
EndProcedure

&AtClient
Procedure SetStandardSettings(Command)
	ReadScannerSettings();
EndProcedure

&AtClient
Procedure OpenScannedFileNumbers(Command)
	OpenForm("InformationRegister.ScannedFileNumbers.ListForm");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function GenerateSetting(Name, Value, ClientID)
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/" + Name);
	Item.Insert("Setting", ClientID);
	Item.Insert("Value", Value);
	Return Item;
	
EndFunction	

&AtClient
Procedure RefreshStatus1()
	
	Items.DeviceName.Enabled = False;
	Items.DeviceName.ChoiceList.Clear();
	Items.DeviceName.ListChoiceMode = False;
	Items.FormatOfScannedImage.Enabled = False;
	Items.Resolution.Enabled = False;
	Items.Chromaticity.Enabled = False;
	Items.Rotation.Enabled = False;
	Items.PaperSize.Enabled = False;
	Items.DoubleSidedScan.Enabled = False;
	Items.SetStandardSettings.Enabled = False;
	
	If Not FileOperationsServiceClient.InitializeComponent() Then
		ScanComponentVersion = NStr("en='Scan component is not installed';ru='Компонента сканирования не установлена'");
		Items.DeviceName.Enabled = False;
		Return;
	EndIf;
		
	Items.SetScanningComponent.Visible = False;
	ScanComponentVersion = FileOperationsServiceClient.ScanComponentVersion();
	
	If Not FileOperationsServiceClient.CommandScanAvailable() Then
		Items.DeviceName.Enabled = False;
		Return;
	EndIf;
		
	DeviceArray = FileOperationsServiceClient.GetDevices();
	For Each String IN DeviceArray Do
		Items.DeviceName.ChoiceList.Add(String);
	EndDo;
	Items.DeviceName.Enabled = True;
	Items.DeviceName.ListChoiceMode = True;
	
	If IsBlankString(DeviceName) Then
		Return;
	EndIf;
		
	Items.FormatOfScannedImage.Enabled = True;
	Items.Resolution.Enabled = True;
	Items.Chromaticity.Enabled = True;
	Items.SetStandardSettings.Enabled = True;
	
	DoubleSidedScanNumber = FileOperationsServiceClient.GetSetting(
		DeviceName, "DUPLEX");
	
	Items.DoubleSidedScan.Enabled = (DoubleSidedScanNumber <> -1);
	
	If Not Resolution.IsEmpty() AND Not Chromaticity.IsEmpty() Then
		Items.Rotation.Enabled = Not Rotation.IsEmpty();
		Items.PaperSize.Enabled = Not PaperSize.IsEmpty();
		Return;
	EndIf;	
		
	PermissionNumber = FileOperationsServiceClient.GetSetting(DeviceName, "XRESOLUTION");
	ChromaticityNumber  = FileOperationsServiceClient.GetSetting(DeviceName, "PIXELTYPE");
	RotationNumber = FileOperationsServiceClient.GetSetting(DeviceName, "ROTATION");
	PaperSizeNumber  = FileOperationsServiceClient.GetSetting(DeviceName, "SUPPORTEDSIZES");
	
	Items.Rotation.Enabled = (RotationNumber <> -1);
	Items.PaperSize.Enabled = (PaperSizeNumber <> -1);
	
	DoubleSidedScan = ? ((DoubleSidedScanNumber = 1), True, False);
	SaveScannerParametersInPreferences(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
						
EndProcedure

&AtServer
Procedure SaveScannerParametersInPreferences(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber) 
	
	ConvertScannerParametersToEnums(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
			
	StructuresArray = New Array;
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/Resolution");
	Item.Insert("Setting", ClientID);
	Item.Insert("Value", Resolution);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/Chromaticity");
	Item.Insert("Setting", ClientID);
	Item.Insert("Value", Chromaticity);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/Rotation");
	Item.Insert("Setting", ClientID);
	Item.Insert("Value", Rotation);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanningSettings/PaperSize");
	Item.Insert("Setting", ClientID);
	Item.Insert("Value", PaperSize);
	StructuresArray.Add(Item);
	
	CommonUse.CommonSettingsStorageSaveArray(StructuresArray);
	
EndProcedure

&AtClient
Procedure ReadScannerSettings()
	
	Items.FormatOfScannedImage.Enabled = Not IsBlankString(DeviceName);
	Items.Resolution.Enabled = Not IsBlankString(DeviceName);
	Items.Chromaticity.Enabled = Not IsBlankString(DeviceName);
	Items.DoubleSidedScan.Enabled = False;
	Items.SetStandardSettings.Enabled = Not IsBlankString(DeviceName);
	
	If IsBlankString(DeviceName) Then
		Items.Rotation.Enabled = False;
		Items.PaperSize.Enabled = False;
		Return;
	EndIf;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Collecting information on scanner ""%1""...';ru='Идет сбор сведений о сканере ""%1""...'"), DeviceName);
	
	Status(MessageText);
	
	PermissionNumber = FileOperationsServiceClient.GetSetting(
		DeviceName, "XRESOLUTION");
	
	ChromaticityNumber = FileOperationsServiceClient.GetSetting(
		DeviceName, "PIXELTYPE");
	
	RotationNumber = FileOperationsServiceClient.GetSetting(
		DeviceName, "ROTATION");
	
	PaperSizeNumber = FileOperationsServiceClient.GetSetting(
		DeviceName, "SUPPORTEDSIZES");
	
	DoubleSidedScanNumber = FileOperationsServiceClient.GetSetting(
		DeviceName, "DUPLEX");
	
	Items.Rotation.Enabled = (RotationNumber <> -1);
	Items.PaperSize.Enabled = (PaperSizeNumber <> -1);
	
	Items.DoubleSidedScan.Enabled = (DoubleSidedScanNumber <> -1);
	DoubleSidedScan = ? ((DoubleSidedScanNumber = 1), True, False);
	
	ConvertScannerParametersToEnums(
		PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
		
	Status();
	
EndProcedure

&AtServer
Procedure ConvertScannerParametersToEnums(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber) 
	
	Result = FileOperationsService.ScannerParametersInEnumerations(PermissionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber);
	Resolution = Result.Resolution;
	Chromaticity = Result.Chromaticity;
	Rotation = Result.Rotation;
	PaperSize = Result.PaperSize;
	
EndProcedure

&AtServer
Function ConvertScanningFormatIntoStorageFormat(ScanningFormat)
	
	If ScanningFormat = Enums.ScannedImagesFormats.BMP Then
		Return Enums.OnePageFilesStorageFormats.BMP;
	ElsIf ScanningFormat = Enums.ScannedImagesFormats.GIF Then
		Return Enums.OnePageFilesStorageFormats.GIF;
	ElsIf ScanningFormat = Enums.ScannedImagesFormats.JPG Then
		Return Enums.OnePageFilesStorageFormats.JPG;
	ElsIf ScanningFormat = Enums.ScannedImagesFormats.PNG Then
		Return Enums.OnePageFilesStorageFormats.PNG; 
	ElsIf ScanningFormat = Enums.ScannedImagesFormats.TIF Then
		Return Enums.OnePageFilesStorageFormats.TIF;
	EndIf;
	
	Return Enums.OnePageFilesStorageFormats.PNG; 
	
EndFunction	

&AtServer
Function ConvertStorageFormatIntoScanningFormat(StorageFormat)
	
	If StorageFormat = Enums.OnePageFilesStorageFormats.BMP Then
		Return Enums.ScannedImagesFormats.BMP;
	ElsIf StorageFormat = Enums.OnePageFilesStorageFormats.GIF Then
		Return Enums.ScannedImagesFormats.GIF;
	ElsIf StorageFormat = Enums.OnePageFilesStorageFormats.JPG Then
		Return Enums.ScannedImagesFormats.JPG;
	ElsIf StorageFormat = Enums.OnePageFilesStorageFormats.PNG Then
		Return Enums.ScannedImagesFormats.PNG; 
	ElsIf StorageFormat = Enums.OnePageFilesStorageFormats.TIF Then
		Return Enums.ScannedImagesFormats.TIF;
	EndIf;
	
	Return FormatOfScannedImage; 
	
EndFunction	

&AtServer
Procedure WorkChangesUseImageMagick()
	
	If Not UseImageMagickForConvertionToPDF Then
		MultiPageStorageFormat = MultiplePagesTIFFormat;
		FormatOfScannedImage = ConvertStorageFormatIntoScanningFormat(OnePageStorageFormat);
		Items.FormatOfScannedImage.Title = NStr("en='Format';ru='Формат'");
	Else
		OnePageStorageFormat = ConvertScanningFormatIntoStorageFormat(FormatOfScannedImage);
		Items.FormatOfScannedImage.Title = NStr("en='Type';ru='Тип'");
	EndIf;	
	
	DecorationsVisible = (UseImageMagickForConvertionToPDF AND (OnePageStorageFormat = OnePagePDFFormat));
	Items.DecorationOnePageStorageFormat.Visible = DecorationsVisible;
	Items.DecorationFormatOfScannedImage.Visible = DecorationsVisible;
	
	ScanningFormatVisible = (UseImageMagickForConvertionToPDF AND (OnePageStorageFormat = OnePagePDFFormat)) OR (NOT UseImageMagickForConvertionToPDF);
	Items.ScanningFormatGroup.Visible = ScanningFormatVisible;
	
	Items.PathToConversionApplication.Enabled = UseImageMagickForConvertionToPDF;
	Items.MultiPageStorageFormat.Enabled = UseImageMagickForConvertionToPDF;
	Items.StorageFormatGroup.Visible = UseImageMagickForConvertionToPDF;	
	
EndProcedure

&AtServer
Procedure WorkChangesOnePageStorageFormat()
	
	Items.ScanningFormatGroup.Visible = (OnePageStorageFormat = OnePagePDFFormat);
	
	If OnePageStorageFormat = OnePagePDFFormat Then
		FormatOfScannedImage = ConvertStorageFormatIntoScanningFormat(OnePageStorageFormatPrevious);
	EndIf;	
	
	DecorationsVisible = (UseImageMagickForConvertionToPDF AND (OnePageStorageFormat = OnePagePDFFormat));
	Items.DecorationOnePageStorageFormat.Visible = DecorationsVisible;
	Items.DecorationFormatOfScannedImage.Visible = DecorationsVisible;
	
	If UseImageMagickForConvertionToPDF Then
		If OnePageStorageFormat = OnePagePDFFormat Then
			Items.JPGQuality.Visible = (FormatOfScannedImage = JPGFormat);
			Items.TIFFCompression.Visible = (FormatOfScannedImage = TIFFormat);
		Else	
			Items.JPGQuality.Visible = (OnePageStorageFormat = OnePageJPGFormat);
			Items.TIFFCompression.Visible = (OnePageStorageFormat = OnePageTIFFormat);
		EndIf;
	Else	
		Items.JPGQuality.Visible = (FormatOfScannedImage = JPGFormat);
		Items.TIFFCompression.Visible = (FormatOfScannedImage = TIFFormat);
	EndIf;
	
	OnePageStorageFormatPrevious = OnePageStorageFormat;
	
EndProcedure

&AtClient
Procedure SetScanningComponentEnd(Result, ExecuteParameters) Export
	RefreshStatus1();
EndProcedure

#EndRegion
