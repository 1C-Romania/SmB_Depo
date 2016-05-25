
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Resolution = Parameters.Resolution;
	Chromaticity = Parameters.Chromaticity;
	Rotation = Parameters.Rotation;
	PaperSize = Parameters.PaperSize;
	DoubleSidedScan = Parameters.DoubleSidedScan;
	UseImageMagickForConvertionToPDF = Parameters.UseImageMagickForConvertionToPDF;
	ShowScannerDialog = Parameters.ShowScannerDialog;
	FormatOfScannedImage = Parameters.FormatOfScannedImage;
	JPGQuality = Parameters.JPGQuality;
	TIFFCompression = Parameters.TIFFCompression;
	OnePageStorageFormat = Parameters.OnePageStorageFormat;
	MultiPageStorageFormat = Parameters.MultiPageStorageFormat;
	
	Items.Rotation.Visible = Parameters.RotationAccessible;
	Items.PaperSize.Visible = Parameters.IsPaperSizeAccessible;
	Items.DoubleSidedScan.Visible = Parameters.EnabledDoubleSidedScan;
	
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
	
	Items.MultiPageStorageFormat.Enabled = UseImageMagickForConvertionToPDF;
	OnePageStorageFormatPrevious = OnePageStorageFormat;
	
	If Not UseImageMagickForConvertionToPDF Then
		Items.FormatOfScannedImage.Title = NStr("en = 'Format'");
	Else
		Items.FormatOfScannedImage.Title = NStr("en = 'Type'");
	EndIf;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject,
		"GroupStorageFormatSingleRow,GroupMultiPageStorageFormat,GroupScanningParameters");
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

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
Procedure OnePageStorageFormatOnChange(Item)
	
	WorkChangesOnePageStorageFormat();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New Structure;
	ChoiceResult.Insert("ShowScannerDialog",  ShowScannerDialog);
	ChoiceResult.Insert("Resolution",               Resolution);
	ChoiceResult.Insert("Chromaticity",                Chromaticity);
	ChoiceResult.Insert("Rotation",                  Rotation);
	ChoiceResult.Insert("PaperSize",             PaperSize);
	ChoiceResult.Insert("DoubleSidedScan", DoubleSidedScan);
	
	ChoiceResult.Insert("UseImageMagickForConvertionToPDF",
		UseImageMagickForConvertionToPDF);
	
	ChoiceResult.Insert("FormatOfScannedImage", FormatOfScannedImage);
	ChoiceResult.Insert("JPGQuality",                     JPGQuality);
	ChoiceResult.Insert("TIFFCompression",                      TIFFCompression);
	ChoiceResult.Insert("OnePageStorageFormat",    OnePageStorageFormat);
	ChoiceResult.Insert("MultiPageStorageFormat",   MultiPageStorageFormat);
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

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

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
