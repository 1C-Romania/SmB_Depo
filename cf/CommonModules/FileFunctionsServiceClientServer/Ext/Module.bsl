////////////////////////////////////////////////////////////////////////////////
// Subsystem "File functions".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Personal settings consist of settings of subsystem FileFunctions.
// (see FileFunctionsServiceReUse.FilesWorkSettings) 
// and also settings of the FileOperations and AttachedFiles subsystems.
//
Function PersonalFileOperationsSettings() Export

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return FileFunctionsServiceReUse.FileOperationsSettings().PersonalSettings;
#Else
	Return FileFunctionsServiceClientReUse.PersonalFileOperationsSettings();
#EndIf

EndFunction

// Personal settings consist of settings of subsystem FileFunctions.
// (see FileFunctionsServiceReUse.FilesWorkSettings)
// and also settings of the FileOperations and AttachedFiles subsystems.
//
Function FileOperationsCommonSettings() Export

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return FileFunctionsServiceReUse.FileOperationsSettings().CommonSettings;
#Else
	Return FileFunctionsServiceClientReUse.FileOperationsCommonSettings();
#EndIf

EndFunction

// Extract a text from the file and return it as a string.
Function ExtractText(FullFileName, Cancel = False, Encoding = Undefined) Export
	
	ExtractedText = "";
	
	Try
		File = New File(FullFileName);
		If Not File.Exist() Then
			Cancel = True;
			Return ExtractedText;
		EndIf;
	Except
		Cancel = True;
		Return ExtractedText;
	EndTry;
	
	Stop = False;
	
	CommonSettings = FileOperationsCommonSettings();
	
#If Not WebClient Then
	
	FileNameExtension =
		CommonUseClientServer.GetFileNameExtension(FullFileName);
	
	FileExtensionInList = FileExtensionInList(
		CommonSettings.TextFileExtensionsList, FileNameExtension);
	
	If FileExtensionInList Then
		Return ExtractTextFromFileTextovogo(FullFileName, Encoding, Cancel);
	EndIf;
	
	Try
		Extraction = New TextExtraction(FullFileName);
		ExtractedText = Extraction.GetText();
	Except
		// When there is nobody to extract a text, an exception is not required. This is a standard case.
		ExtractedText = "";
		Stop = True;
	EndTry;
#EndIf
	
	If IsBlankString(ExtractedText) Then
		
		FileNameExtension =
			CommonUseClientServer.GetFileNameExtension(FullFileName);
		
		FileExtensionInList = FileExtensionInList(
			CommonSettings.FileExtensionListOpenDocument, FileNameExtension);
		
		If FileExtensionInList Then
			Return ExtractOpenDocumentText(FullFileName, Cancel);
		EndIf;
		
	EndIf;
	
	If Stop Then
		Cancel = True;
	EndIf;
	
	Return ExtractedText;
	
EndFunction

// Extract a text from file and place it in a temporary storage.
Function ExtractTextToTemporaryStorage(FullFileName, UUID = "", Cancel = False,
	Encoding = Undefined) Export
	
	TemporaryStorageAddress = "";
	
	#If Not WebClient Then
		
		Text = ExtractText(FullFileName, Cancel, Encoding);
		
		If IsBlankString(Text) Then
			Return "";
		EndIf;
		
		TempFileName = GetTempFileName();
		TextFile = New TextWriter(TempFileName, TextEncoding.UTF8);
		TextFile.Write(Text);
		TextFile.Close();
		
		#If Client Then
			ImportResult = FileFunctionsServiceClient.PutFileFromDiskToTemporaryStorage(TempFileName, , UUID);
			If ImportResult <> Undefined Then
				TemporaryStorageAddress = ImportResult;
			EndIf;
		#Else
			Return Text;
		#EndIf
		
		DeleteFiles(TempFileName);
		
	#EndIf
	
	Return TemporaryStorageAddress;
	
EndFunction

// Get a unique attachment file name in a working directory.
//  If there are matches - name similar to "A1\Order.doc".
//
Function GetUniqueNameWithPath(DirectoryName, FileName) Export
	
	FinalPath = "";
	
	Counter = 0;
	CycleNumber = 0;
	Successfully = False;
	
	GeneratorCase = Undefined;
	
#If Not WebClient Then
	// CurrentDate() used only for random number generation
	// as cast to SessionCurrentDate is not necessary.
	GeneratorCase = New RandomNumberGenerator(Second(CurrentDate()));
#EndIf
	
	While Not Successfully AND CycleNumber < 100 Do
		NumberDirectory = 0;
#If Not WebClient Then
		NumberDirectory = GeneratorCase.RandomNumber(0, 25);
#Else
		// CurrentDate() used only for random number generation
		// as cast to SessionCurrentDate is not necessary.
		NumberDirectory = Second(CurrentDate()) % 26;
#EndIf
		
		CodeLetterA = CharCode("A", 1); 
		DirectoryCode = CodeLetterA + NumberDirectory;
		
		LetterOfDirectory = Char(DirectoryCode);
		
		Subdirectory = ""; // Partial path.
		
		// By default, first a root is used,
		// if it is impossible, then A,B, ... are added Z,  A1, B1, .. Z1, ..  A2, B2, etc.
		If  Counter = 0 Then
			Subdirectory = "";
		Else
			Subdirectory = LetterOfDirectory; 
			CycleNumber = Round(Counter / 26);
			
			If CycleNumber <> 0 Then
				DoNumberRow = String(CycleNumber);
				Subdirectory = Subdirectory + DoNumberRow;
			EndIf;
			
			Subdirectory = CommonUseClientServer.AddFinalPathSeparator(Subdirectory);
		EndIf;
		
		FullSubDirectory = DirectoryName + Subdirectory;
		
		// Creating a file directory.
		DirectoryOnHardDisk = New File(FullSubDirectory);
		If Not DirectoryOnHardDisk.Exist() Then
			Try
				CreateDirectory(FullSubDirectory);
			Except
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='An error occurred when
		|creating directory ""%1"": ""%2"".';ru='Ошибка при
		|создании каталога ""%1"": ""%2"".'"),
					FullSubDirectory,
					BriefErrorDescription(ErrorInfo()) );
			EndTry;
		EndIf;
		
		FileOFAttempt = FullSubDirectory + FileName;
		Counter = Counter + 1;
		
		// Checks whether a file with such name exists.
		FileOnDrive = New File(FileOFAttempt);
		If Not FileOnDrive.Exist() Then  // Such file does not exist.
			FinalPath = Subdirectory + FileName;
			Successfully = True;
		EndIf;
	EndDo;
	
	Return FinalPath;
	
EndFunction

// Returns True if a file with such extension is in an extension list.
Function FileExtensionInList(ExtensionsList, FileExtension) Export
	
	FileExtensionWithoutDot = CommonUseClientServer.ExtensionWithoutDot(FileExtension);
	
	ArrayExtensions = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
		Lower(ExtensionsList), " ");
	
	If ArrayExtensions.Find(FileExtensionWithoutDot) <> Undefined Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Checks the file size and extension.
Function CheckFileImportingPossibility(File,
                                          CallingException = True,
                                          FilenamesWithErrorsArray = Undefined) Export
	
	CommonSettings = FileOperationsCommonSettings();
	
	// The file size is too big.
	If File.Size() > CommonSettings.MaximumFileSize Then
		
		SizeInMB     = File.Size() / (1024 * 1024);
		SizeInMbMax = CommonSettings.MaximumFileSize / (1024 * 1024);
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Size of the file
		|""%1"" (%2 Mb) exceeds the maximum allowed file size (%3Mb).';ru='Размер файла
		|""%1"" (%2 Мб) превышает максимально допустимый размер файла (%3 Мб).'"),
			File.Name,
			GetStringWithFileSize(SizeInMB),
			GetStringWithFileSize(SizeInMbMax));
		
		If CallingException Then
			Raise ErrorDescription;
		EndIf;
		
		Record = New Structure;
		Record.Insert("FileName", File.DescriptionFull);
		Record.Insert("Error",   ErrorDescription);
		
		FilenamesWithErrorsArray.Add(Record);
		Return False;
	EndIf;
	
	// Checking a file extension.
	If Not CheckFileExtensionForImporting(File.Extension, False) Then
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cannot import files with extension ""%1"".
		|Contact your administrator.';ru='Загрузка файлов с расширением ""%1"" запрещена.
		|Обратитесь к администратору.'"),
			File.Extension);
		
		If CallingException Then
			Raise ErrorDescription;
		EndIf;
		
		Record = New Structure;
		Record.Insert("FileName", File.DescriptionFull);
		Record.Insert("Error",   ErrorDescription);
		
		FilenamesWithErrorsArray.Add(Record);
		Return False;
	EndIf;
	
	// Temporary Word files are not imported.
	If Left(File.Name, 1) = "~"
	   AND File.GetHidden() = True Then
		
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns True if a file with such extension can be imported.
Function CheckFileExtensionForImporting(FileExtension, CallingException = True) Export
	
	CommonSettings = FileOperationsCommonSettings();
	
	If Not CommonSettings.ImportingFilesByExtensionProhibition Then
		Return True;
	EndIf;
	
	If FileExtensionInList(CommonSettings.ProhibitedExtensionsList, FileExtension) Then
		
		If CallingException Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Cannot import files with extension ""%1"".
		|Contact your administrator.';ru='Загрузка файлов с расширением ""%1"" запрещена.
		|Обратитесь к администратору.'"),
				FileExtension);
		Else
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// It calls an exception if a file size is too large for import.
Procedure CheckFileSizeForImporting(File) Export
	
	CommonSettings = FileOperationsCommonSettings();
	
	If TypeOf(File) = Type("File") Then
		Size = File.Size();
	Else
		Size = File.Size;
	EndIf;
	
	If Size > CommonSettings.MaximumFileSize Then
	
		SizeInMB     = Size / (1024 * 1024);
		SizeInMbMax = CommonSettings.MaximumFileSize / (1024 * 1024);
		
		If TypeOf(File) = Type("File") Then
			Name = File.Name;
		Else
			Name = CommonUseClientServer.GetNameWithExtention(
				File.FullDescr, File.Extension);
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Size of the file
		|""%1"" (%2 Mb) exceeds the maximum allowed file size (%3Mb).';ru='Размер файла
		|""%1"" (%2 Мб) превышает максимально допустимый размер файла (%3 Мб).'"),
			Name,
			GetStringWithFileSize(SizeInMB),
			GetStringWithFileSize(SizeInMbMax));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For user interface.

// Returns a message prompting that a locked file can not be signed.
//
Function MessageStringAboutImpossibilityOfLockedFileSigning(FileRef = Undefined) Export
	
	If FileRef = Undefined Then
		Return NStr("en='Cannot sign locked file.';ru='Нельзя подписать занятый файл.'");
	Else
		Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cannot sign locked file: %1.';ru='Нельзя подписать занятый файл: %1.'"),
			String(FileRef) );
	EndIf;
	
EndFunction

// Returns a message prompting that an encrypted file can not be signed.
//
Function MessageStringAboutImpossibilityOfEncryptedFileSigning(FileRef = Undefined) Export
	
	If FileRef = Undefined Then
		Return NStr("en='Cannot sign encrypted file.';ru='Нельзя подписать зашифрованный файл.'");
	Else
		Return StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en='Cannot sign encrypted file: %1.';ru='Нельзя подписать зашифрованный файл: %1.'"),
						String(FileRef) );
	EndIf;
	
EndFunction

// Returns a message text of the error that occurred on creating a new file.
//
// Parameters:
//  ErrorInfo - ErrorInfo.
//
Function NewFileCreationError(ErrorInfo) Export
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='An error occurred when creating a new file.
		|
		|%1';ru='Ошибка создания нового файла.
		|
		|%1'"),
		BriefErrorDescription(ErrorInfo));

EndFunction

// Returns a standard error text.
Function ErrorFileIsNotFoundInFileStorage(FileName, SearchInVolume = True) Export
	
	If SearchInVolume Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='An error
		|occurred while opening file ""%1"".
		|
		|File is not found in the file storage.
		|The file might have been deleted by an antivirus software.
		|Contact your administrator.';ru='Ошибка
		|открытия файла: ""%1"".
		|
		|Файл не найден в хранилище файлов.
		|Возможно файл удален антивирусной программой.
		|Обратитесь к администратору.'"),
			FileName);
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='An error
		|occurred while opening file ""%1"".
		|
		|File is not found in the file storage.
		|Contact your administrator.';ru='Ошибка
		|открытия файла: ""%1"".
		|
		|Файл не найден в хранилище файлов.
		|Обратитесь к администратору.'"),
			FileName);
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Get a string with a file size presentation. - for example, to show State when transferring a file.
Function GetStringWithFileSize(Val SizeInMB) Export
	
	If SizeInMB < 0.1 Then
		SizeInMB = 0.1;
	EndIf;	
	
	StringOfSize = ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0"));
	Return StringOfSize;
	
EndFunction	

// The result is the index of file icon - index in the picture FileIconCollection.
Function GetFileIconIndex(Val FileExtension) Export
	
	If TypeOf(FileExtension) <> Type("String")
	 OR IsBlankString(FileExtension) Then
		
		Return 0;
	EndIf;
	
	FileExtension = CommonUseClientServer.ExtensionWithoutDot(FileExtension);
	
	Extension = "." + Lower(FileExtension) + ";";
	
	If Find(".dt;.1Cd;.cf;.cfu;", Extension) <> 0 Then
		Return 6; // 1C files.
		
	ElsIf Extension = ".mxl;" Then
		Return 8; // Tabular File.
		
	ElsIf Find(".txt;.log;.ini;", Extension) <> 0 Then
		Return 10; // Text file.
		
	ElsIf Extension = ".epf;" Then
		Return 12; // External data processors.
		
	ElsIf Find(".ico;.wmf;.emf;",Extension) <> 0 Then
		Return 14; // Images.
		
	ElsIf Find(".htm;.html;.url;.mht;.mhtml;",Extension) <> 0 Then
		Return 16; // HTML.
		
	ElsIf Find(".doc;.dot;.rtf;",Extension) <> 0 Then
		Return 18; // File Microsoft Word.
		
	ElsIf Find(".xls;.xlw;",Extension) <> 0 Then
		Return 20; // File Microsoft Excel.
		
	ElsIf Find(".ppt;.pps;",Extension) <> 0 Then
		Return 22; // File Microsoft PowerPoint.
		
	ElsIf Find(".vsd;",Extension) <> 0 Then
		Return 24; // File Microsoft Visio.
		
	ElsIf Find(".mpp;",Extension) <> 0 Then
		Return 26; // File Microsoft Visio.
		
	ElsIf Find(".mdb;.adp;.mda;.mde;.ade;",Extension) <> 0 Then
		Return 28; // Database Microsoft Access.
		
	ElsIf Find(".xml;",Extension) <> 0 Then
		Return 30; // xml.
		
	ElsIf Find(".msg;",Extension) <> 0 Then
		Return 32; // Email.
		
	ElsIf Find(".zip;.rar;.arj;.cab;.lzh;.ace;",Extension) <> 0 Then
		Return 34; // archives.
		
	ElsIf Find(".exe;.com;.bat;.cmd;",Extension) <> 0 Then
		Return 36; // Executable files.
		
	ElsIf Find(".grs;",Extension) <> 0 Then
		Return 38; // Graphic scheme.
		
	ElsIf Find(".geo;",Extension) <> 0 Then
		Return 40; // Geographical scheme.
		
	ElsIf Find(".jpg;.jpeg;.jp2;.jpe;",Extension) <> 0 Then
		Return 42; // jpg.
		
	ElsIf Find(".bmp;.dib;",Extension) <> 0 Then
		Return 44; // bmp.
		
	ElsIf Find(".tif;.tiff;",Extension) <> 0 Then
		Return 46; // tif.
		
	ElsIf Find(".gif;",Extension) <> 0 Then
		Return 48; // gif.
		
	ElsIf Find(".png;",Extension) <> 0 Then
		Return 50; // png.
		
	ElsIf Find(".pdf;",Extension) <> 0 Then
		Return 52; // pdf.
		
	ElsIf Find(".odt;",Extension) <> 0 Then
		Return 54; // Open Office writer.
		
	ElsIf Find(".odf;",Extension) <> 0 Then
		Return 56; // Open Office math.
		
	ElsIf Find(".odp;",Extension) <> 0 Then
		Return 58; // Open Office Impress.
		
	ElsIf Find(".odg;",Extension) <> 0 Then
		Return 60; // Open Office draw.
		
	ElsIf Find(".ods;",Extension) <> 0 Then
		Return 62; // Open Office calc.
		
	ElsIf Find(".mp3;",Extension) <> 0 Then
		Return 64;
		
	ElsIf Find(".erf;",Extension) <> 0 Then
		Return 66; // External reports.
		
	ElsIf Find(".docx;",Extension) <> 0 Then
		Return 68; // File Microsoft Word docx.
		
	ElsIf Find(".xlsx;",Extension) <> 0 Then
		Return 70; // File Microsoft Excel xlsx.
		
	ElsIf Find(".pptx;",Extension) <> 0 Then
		Return 72; // File Microsoft PowerPoint pptx.
		
	ElsIf Find(".p7s;",Extension) <> 0 Then
		Return 74; // Signature file.
		
	ElsIf Find(".p7m;",Extension) <> 0 Then
		Return 76; // encrypted message.
	Else
		Return 4;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other

// Deletes files after import or import.
Procedure DeleteFilesAfterAdd1(AllFilesStructuresArray, AllFoldersArray, ImportMode) Export
	
	For Each Item IN AllFilesStructuresArray Do
		SelectedFile = New File(Item.FileName);
		SelectedFile.SetReadOnly(False);
		DeleteFiles(SelectedFile.DescriptionFull);
	EndDo;
	
	If ImportMode Then
		For Each Item IN AllFoldersArray Do
			FoundFiles = FindFiles(Item, "*.*");
			If FoundFiles.Count() = 0 Then
				SelectedFile = New File(Item);
				SelectedFile.SetReadOnly(False);
				DeleteFiles(SelectedFile.DescriptionFull);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure	

// Returns a file array emulating FindFiles - but not by the file system
//  and compliance if PseudoFileSystem is empty - works with a file system.
Function FindFilesPseudo(Val PseudoFileSystem, Path) Export
	
	If PseudoFileSystem.Count() = 0 Then
		Files = FindFiles(Path, "*.*");
		Return Files;
	EndIf;
	
	Files = New Array;
	
	ValueFound = PseudoFileSystem.Get(String(Path));
	If ValueFound <> Undefined Then
		For Each FileName IN ValueFound Do
			FileFromList = New File(FileName);
			Files.Add(FileFromList);
		EndDo;
	EndIf;
	
	Return Files;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Helper procedure and functions.

// Extracts a text according to the encoding.
// If encoding is not set - it calculates encoding.
//
Function ExtractTextFromFileTextovogo(FullFileName, Encoding, Cancel)
	
	ExtractedText = "";
	
#If Not WebClient Then
	
	// Define encoding.
	If Not ValueIsFilled(Encoding) Then
		Encoding = Undefined;
	EndIf;
	
	Try
		TextReader = New TextReader(FullFileName, Encoding);
		ExtractedText = TextReader.Read();
	Except
		Cancel = True;
		ExtractedText = "";
	EndTry;
	
#EndIf
	
	Return ExtractedText;
	
EndFunction

// Extract a text from file OpenDocument and return it as a string.
//
Function ExtractOpenDocumentText(PathToFile, Cancel)
	
	ExtractedText = "";
	
#If Not WebClient Then
	
	TemporaryFolderToUnpacking = GetTempFileName("");
	TemporaryZIPFile = GetTempFileName("zip"); 
	
	FileCopy(PathToFile, TemporaryZIPFile);
	File = New File(TemporaryZIPFile);
	File.SetReadOnly(False);

	Try
		archive = New ZipFileReader();
		archive.Open(TemporaryZIPFile);
		archive.ExtractAll(TemporaryFolderToUnpacking, ZIPRestoreFilePathsMode.Restore);
		archive.Close();
		XMLReader = New XMLReader();
		
		XMLReader.OpenFile(TemporaryFolderToUnpacking + "/content.xml");
		ExtractedText = ExtractTextFromContentXML(XMLReader);
		XMLReader.Close();
	Except
		// It is not an error as for example, extension OTF can be both OpenDocument and font OpenType.
		Cancel = True;
		ExtractedText = "";
	EndTry;
	
	DeleteFiles(TemporaryFolderToUnpacking);
	DeleteFiles(TemporaryZIPFile);
	
#EndIf
	
	Return ExtractedText;
	
EndFunction

// Extract text from the XMLReader object read from file OpenDocument).
Function ExtractTextFromContentXML(XMLReader)
	
	ExtractedText = "";
	LastTagName = "";
	
#If Not WebClient Then
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			
			LastTagName = XMLReader.Name;
			
			If XMLReader.Name = "text:p" Then
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.LF;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:line-break" Then
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.LF;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:tab" Then
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.Tab;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:s" Then
				
				AddingString = " "; // space
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.Name = "text:c"  Then
							SpacesNumber = Number(XMLReader.Value);
							AddingString = "";
							For IndexOf = 0 To SpacesNumber - 1 Do
								AddingString = AddingString + " "; // space
							EndDo;
						EndIf;
					EndDo
				EndIf;
				
				If Not IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + AddingString;
				EndIf;
			EndIf;
			
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.Text Then
			
			If Find(LastTagName, "text:") <> 0 Then
				ExtractedText = ExtractedText + XMLReader.Value;
			EndIf;
			
		EndIf;
		
	EndDo;
	
#EndIf

	Return ExtractedText;
	
EndFunction	

#EndRegion
