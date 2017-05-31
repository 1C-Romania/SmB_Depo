
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH FILES FOR ADDITIONAL INFORMATION MECHANICS

// Generates file fullname from directory name and file name
//
// Parameters
//  CatalogName  – String, Path to file on disk
//  FileName     – String, file name without directory
//
// Return Value:
//   String – full file name with directory
//
Function GetFileName(CatalogName, FileName) Export

	If Not IsBlankString(FileName) Then
		
		Return CatalogName + ?(Right(CatalogName, 1) = "\", "", "\") + FileName;	
		
	Else
		
		Return CatalogName;
		
	EndIf;

EndFunction // GetFileName()

// Procedure full file name divide on path to file and file name
//
// Parameters
//  FullFileName  – String, full file name with directory
//  CatalogName  –  String, path to file on disk
//  FileName     – String, full file name without directory
//
Procedure GetDirectoryAndFileName(Val FullFileName, CatalogName, FileName) Export
	
	// searching first symbol "\" from and. All symbols before - path to file; after - file name
	PositionNumber = StrLen(FullFileName);
	While PositionNumber <> 0 Do
		
		If Mid(FullFileName, PositionNumber, 1) = "\" Then
			
			CatalogName = Mid(FullFileName, 1, PositionNumber - 1);
			FileName = Mid(FullFileName, PositionNumber + 1);
			Return;
			
		EndIf;
		
		PositionNumber = PositionNumber - 1;
		
	EndDo;
	
	// there is no slash, so this is a file name
	FileName = FullFileName;
	CatalogName = "";
	
EndProcedure

// Procedure changes files extention 
//
// Parameters
//  FileName  – String, full file name
//  NewFileExtension  – string, new file extension
//
Procedure SetFileExtension(FileName, Val NewFileExtension) Export
	
	// add dot to extension
	If Mid(NewFileExtension, 1, 1) <> "." Then
		ExtensionNewValue = "." + NewFileExtension;	
	Else
		ExtensionNewValue = NewFileExtension;	
	EndIf;
	// if dot not found in current filename, so add new extension to file end
	DotPosition = StrLen(FileName);
	While DotPosition >= 1 Do
		
		If Mid(FileName, DotPosition, 1) = "." Then
						
			FileName = Mid(FileName, 1, DotPosition - 1) + ExtensionNewValue;
			Return; 
			
		EndIf;
		
		DotPosition = DotPosition - 1;	
	EndDo;
	
	// dot not found
	FileName = FileName + ExtensionNewValue;	
	
EndProcedure

// Generates directory name for saving reading files. For different objects types possible different algorithm of directory determining
//
Function GetDirectoryName() Export

	WorkDir = TempFilesDir();

	If Right(WorkDir, 1) = "\" OR Right(WorkDir, 1) = "/" Then
		WorkDir = Left(WorkDir, StrLen(WorkDir) - 1);
	EndIf;

	Return WorkDir;

EndFunction // GetDirectoryName()

#If Client Then
	
// Creates and sets attributes for filedialog
//
// Parameters
//  multiselect – Boolean, multiselect flag.
//  StartingDirectory – String, creates starting directory for choosing file
//
// Return value:
//   FilesDialog – created dialog.
//
Function GetChooseFileDialog(Multiselect, StartingDirectory = "") Export

	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Directory = StartingDirectory;
	Dialog.Title = Nstr("en='Choose file...';pl='Wybierz plik...'");
	Dialog.Filter = GetFilesFilter();
	Dialog.Preview = True;
	Dialog.CheckFileExist = True;
	Dialog.Multiselect = Multiselect;

	Return Dialog;

EndFunction // GetChooseFileDialog()



// Save file on disk
//
// Parameters
//  Valuestorage    – ValueStorage, which contains object with type 
//                 BinaryData with file for writting on disk
//  FileName     – String, contains full filename
//  ReadOnly – Boolean, set to file RO attribute
//  RewriteMode – String. Parameter determines rewriting mode for already existing files on disk.
//                 Depending on passing parameter appeares query about rewriting file.
//                 "" (empty string) - means that query dialog never was shown, and if file exists
//                 on disk query dialog appears
//                 YES - previous file was overwritted,  but should be query for current
//                 NO - previous file was not overwritted,  but should be query for current
//                 FORALL - previous file was overwritted, and all next files also should be ovewritted
//                 NOFORALL - previous file was not overwritted, and all next files also should not be ovewritted
//
// Return value:
//   Boolean – True, if directory selected, False, if not.
//
Function SaveFileOnDisk(Valuestorage, FileName, ReadOnly, RewriteMode, QueryOnRewrite = True, CatalogName = "AdditionalInformationRepository") Export

	Try

		FileOnDisk = New File(FileName);
		DirectoryOnDisk = New File(FileOnDisk.Path);

		If Not DirectoryOnDisk.Exist() Then
			CreateDirectory(FileOnDisk.Path);
		EndIf;

		If FileOnDisk.Exist() AND QueryOnRewrite = True Then

			If RewriteMode = ""
			 OR Upper(RewriteMode) = "YES"
			 OR Upper(RewriteMode) = "NO" Then

				//FilesOverwriteQueryForm = Catalogs[CatalogName].GetForm("FilesOverwriteQueryForm");
				FilesOverwriteQueryForm = GetCommonForm("FilesOverwriteQueryForm");
				FilesOverwriteQueryForm.QueryText = 
				Alerts.ParametrizeString(Nstr("en = 'On local drive already exist file
                                               |%P1. Overwrite existing file?'; pl = 'Na dysku lokalnym istnieje plik
                                               |%P1. Nadpisać istniejący plik?'"),New Structure("P1",FileName));
				RewriteMode = FilesOverwriteQueryForm.DoModal();

				If RewriteMode = Undefined
				 OR Upper(RewriteMode) = "NO"
				 OR Upper(RewriteMode) = "NOFORALL" Then
					Return False;
				EndIf;

			ElsIf Upper(RewriteMode) = "NOFORALL" Then

				Return False;

			EndIf;

			If FileOnDisk.GetReadOnly() Then
				FileOnDisk.SetReadOnly(False);
			EndIf;

		EndIf;

		// remain cases when:
		// - user answer Yes or YesForAll in current dialog
		// - overwrite mode passed with value YesForAll
		If TypeOf(Valuestorage) <> Type("BinaryData") Then
			BinaryData = Valuestorage.Get();
		Else
			BinaryData = Valuestorage;
		EndIf; 
		BinaryData.Write(FileName);
		FileOnDisk.SetReadOnly(ReadOnly);

	Except

		ShowMessageBox(, ErrorDescription());
		Return False;

	EndTry;

	Return True;

EndFunction // SaveFileOnDisk()

// Save on disk selected files.
//
// Parameters
//  FilesObject  - Ref on object , for which attach files
//  SelectedRows - SelectedRows 
Procedure SaveFiles(FilesObject, SelectedRows, DirectoryName = Undefined, CatalogName = "AdditionalInformationRepository") Export

	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;

	//SavingFilesForm = Catalogs[CatalogName].GetForm("SavingFilesForm");
	SavingFilesForm = GetCommonForm("SavingFilesForm");
	SavingFilesForm.DirectoryName    = DirectoryName;
	SavingFilesForm.ReadOnly   = False;

	If CatalogName = Undefined Then
		CatalogName = GetDirectoryName();
		SavingFilesForm.OpenDirectory = True;
	Else
		SavingFilesForm.OpenDirectory = False;
	EndIf; 

	ParametersStructure = SavingFilesForm.DoModal();
	
	If ParametersStructure = Undefined Then
		Return;
	EndIf;

	If Not CheckFolderExisting(ParametersStructure.DirectoryName) Then
		Return;
	EndIf;

	OverwriteMode = "";

	For each RefFile in SelectedRows Do

		Status(Nstr("en='Saving file';pl='Zapisywanie pliku'")+": " + RefFile.FileName);

		FileName = GetFileName(ParametersStructure.DirectoryName, RefFile.FileName);
		SaveFileOnDisk(RefFile.Valuestorage, FileName, ParametersStructure.ReadOnly, OverwriteMode);

		If OverwriteMode = Undefined Then
			Break;
		EndIf; 

	EndDo;

	If ParametersStructure.OpenDirectory Then
		RunApp(ParametersStructure.DirectoryName);
	EndIf;

EndProcedure // SaveFiles()


// Opens passed file considiration with file type. Files with which can work 1C:Enterprise,
// opens in 1C, other files tryed to be opened through windows mechanics.
//
// Parameters
//  CatalogName  – Directory name to file
//  FileName     – File name without directory name
//
Procedure OpenFileAdditionalInformation(CatalogName, FileName) Export

	FullFileName = GetFileName(CatalogName, FileName);
	FilesExtension = Upper(GetFileExtension(FileName));

	If FilesExtension = "MXL" Then

		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.Read(FullFileName);
		SpreadsheetDocument.Show(FileName, Left(FileName, StrLen(FileName) - 4));

	ElsIf FilesExtension = "TXT" Then

		TextDocument = New TextDocument;
		TextDocument.Read(FullFileName);
		TextDocument.Show(FileName, Left(FileName, StrLen(FileName) - 4));

	ElsIf FilesExtension = "EPF" Then

		ExternalDataProcessor = ExternalDataProcessors.Create(FullFileName);
		ExternalDataProcessor.GetForm().Open();

	Else

		RunApp(FullFileName);

	EndIf;

EndProcedure // OpenFileAdditionalInformation()

// Save on disk object selected files and opens them
//
// Parameters
//  FilesObject  - Ref on object, for which attached files
//  SelectedRows - tablebox selected rows 
//
Procedure OpenFiles(FilesObject, SelectedRows = Undefined, QueryOnRewrite = True) Export

	If SelectedRows = Undefined Then
				
		CatalogName = GetDirectoryName();
		ReadOnly = False;

		OverwriteMode = "";

		Status(Nstr("en='Saving file';pl='Zapisywanie pliku'")+": " + FilesObject.FileName);

		FileName = GetFileName(CatalogName, FilesObject.FileName);
		SaveFileOnDisk(FilesObject.Valuestorage, FileName, False, OverwriteMode, QueryOnRewrite);

		If OverwriteMode = Undefined Then
			Return;
		EndIf;

		OpenFileAdditionalInformation(CatalogName, FilesObject.FileName);
		
	Else
		
		If SelectedRows.Count() = 0 Then
			Return;
		EndIf;

		CatalogName = GetDirectoryName();
		ReadOnly = False;

		OverwriteMode = "";

		For each FileRef in SelectedRows Do
			
			Status(Nstr("en='Saving file';pl='Zapisywanie pliku'")+": " + FileRef.FileName);

			FileName = GetFileName(CatalogName, FileRef.FileName);
			SaveFileOnDisk(FileRef.Valuestorage, FileName, False, OverwriteMode, QueryOnRewrite);

			If OverwriteMode = Undefined Then
				Break;
			EndIf;

			OpenFileAdditionalInformation(CatalogName, FileRef.FileName);

		EndDo;
		
	EndIf; 
	
EndProcedure // OpenFiles()

// Check possibility of changing files extension. Ask user about extension changing
//
// Parameters
//  CurrentExtension – String, extension before change.
//  NewExtension – String, extension after change
//
// Return value:
//   Boolean – True, if user don't allow extension changing, False, if allow.
//
Function ProhibitedToChangeExtension(CurrentExtension, NewExtension) Export

	If Not IsBlankString(CurrentExtension) AND Not NewExtension = CurrentExtension Then

		Response = Doquerybox(Nstr("en='Are you sure you want to change file extension?';pl='Jesteś pewien, że chcesz zmienić rozszerzenie pliku?'"), QuestionDialogMode.YesNo);

		If Response = DialogReturnCode.Yes Then

			Return False;

		Else

			Return True;

		EndIf;

	Else

		Return False;

	EndIf;

EndFunction // ProhibitedToChangeExtension()

#EndIf

Function IsFolderExist(FolderPath) Export
	
	If NOT IsBlankString(FolderPath) Then
		Dir = New File(FolderPath);
		If Dir.Exist() AND Dir.IsDirectory() Then
			Return True;	
		EndIf;	
	EndIf;	
	
	Return False;
	
EndFunction	

// Function determines last modification date of existing file
// Parameters
//  FileName  – String, full file name
//
// Return Value:
//   Date – Last modification date
//
Function GetFileDate(Val FileName) Export
	
	File = New File(FileName);
	Return File.GetModificationTime();
	 
EndFunction

// Generates string with filter (for files types) for filedialog
//
// Parameters
//  None
//
// Return Value:
//   String – filter 
//
Function GetFilesFilter() Export

	Return "All files (*.*)|*.*|"
	      + "Document Microsoft Word (*.doc)|*.doc|"
	      + "Document Microsoft Excel (*.XLS)|*.XLS|"
	      + "Document Microsoft Excel 2007-... (*.XLSX)|*.XLSX|"
	      + "Document Microsoft PowerPoint (*.ppt)|*.ppt|"
	      + "Document Microsoft Visio (*.vsd)|*.vsd|"
	      + "E-mail message (*.msg)|*.msg|"
	      + "Pictures (*.BMP;*.dib;*.rle;*.jpg;*.JPEG;*.tif;*.GIF;*.PNG;*.ico;*.WMF;*.EMF)|*.BMP;*.dib;*.rle;*.jpg;*.JPEG;*.tif;*.GIF;*.PNG;*.ico;*.WMF;*.EMF|"
	      + "Text document (*.TXT)|*.TXT|"
	      + "Spreadsheet document (*.MXL)|*.MXL|";

EndFunction // GetFilesFilter()

// Generates string with filter for choosen pictures
//
// Parameters
//  None
//
// Return Value:
//   String – filter
//
Function GetImageFilter() Export

	Return "All pictures (*.BMP;*.dib;*.rle;*.jpg;*.JPEG;*.tif;*.GIF;*.PNG;*.ico;*.WMF;*.EMF)|*.BMP;*.dib;*.rle;*.jpg;*.JPEG;*.tif;*.GIF;*.PNG;*.ico;*.WMF;*.EMF|" 
	      + "Format BMP (*.BMP;*.dib;*.rle)|*.BMP;*.dib;*.rle|"
	      + "Format JPEG (*.jpg;*.JPEG)|*.jpg;*.JPEG|"
	      + "Format TIFF (*.tif)|*.tif|"
	      + "Format GIF (*.GIF)|*.GIF|"
	      + "Format PNG (*.PNG)|*.PNG|"
	      + "Format Icon (*.ico)|*.ico|"
	      + "Format metafile (*.WMF;*.EMF)|*.WMF;*.EMF|";

EndFunction // GetImageFilter()

// function return list of forbidden symbols in file names
// Return Value:
//   ValueList in which stored list of forbidden symbols
//
Function GetListOfSymbolsForbiddenInFileName()
	
	SymbolsList = New ValueList();
	
	SymbolsList.Add("\");
	SymbolsList.Add("/");
	SymbolsList.Add(":");
	SymbolsList.Add("*");
	SymbolsList.Add("&");
	SymbolsList.Add("""");
	SymbolsList.Add("<");
	SymbolsList.Add(">");
	SymbolsList.Add("|");
	
	Return SymbolsList;
	
EndFunction

// Check existing forbidden symbols in filename
//
// Parameters
//  FileName     – String, filename without directory.
//
// Return Value:
//   Boolean – True, if is there are forbidden symbols, False, if not.
//
Function IsForbiddenSymbols(FileName) Export

	If IsBlankString(FileName) Then
		Return False;
	EndIf;
	
	SymbolsList = GetListOfSymbolsForbiddenInFileName();
	
	For Each ForbiddenSymbolString  In SymbolsList Do
		
		If Find(FileName,  ForbiddenSymbolString.Value) > 0 Then
			
			Return True;
			
		EndIf;
			
	EndDo;
	
	Return False;
    	
EndFunction // IsForbiddenSymbols()

// function generates file name and deletes from given filename all forbidden symbols
// forbiddent symbols
// Parameters
//  FileName     – String, filename without directory
//
// Return Value:
//   String – file name, without forbidden symbols
//
Function RemoveForbiddenSymbolsInName(Val FileName) Export

	ResultingFileName = TrimAll(FileName);
	
	If IsBlankString(ResultingFileName) Then
		
		Return ResultingFileName;
		
	EndIf;
	
	SymbolsList = GetListOfSymbolsForbiddenInFileName();
	
	For Each ForbiddenSymbolString  In SymbolsList Do
		
		ResultingFileName = StrReplace(ResultingFileName,  ForbiddenSymbolString.Value, "");			
		
	EndDo;
	
	Return ResultingFileName;

EndFunction // RemoveForbiddenSymbolsInName()

#If Client Then

// Check directory existance, and if does not exists then query on creation
//
// Parameters
//  CatalogName  – String, path to file
//
// Return Value:
//   Boolean – True, if directory exist or created, False, if directory not found.
//
Function CheckFolderExisting(CatalogName) Export

	DirectoryOnDisk = New File(CatalogName);
	If DirectoryOnDisk.Exist() Then
		Return True;
	Else
		Response = Doquerybox(Nstr("en='Specified folder does not exist. Do you want to create a folder?';pl='Wskazany folder nie istnieje. Czy utworzyć folder?'"), QuestionDialogMode.YesNo);
		If Response = DialogReturnCode.Yes Then
			
			CreateDirectory(CatalogName);
			Return True;
			
		Else
			
			Return False;
			
		EndIf;
	EndIf;

EndFunction // CheckFolderExisting()
	
// Allows to user choose directory
//
// Parameters
//  CatalogName  – String, path to file
//	DialogTitle - String, dialog title
//
// Return Value:
//   Boolean – True, if directory selected, False, if not.
//
Function ChooseFolder(CatalogName, Val DialogTitle = "Choose directory") Export

	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	Dialog.Title = DialogTitle;
	Dialog.multiselect = False;
	Dialog.Directory = CatalogName;

	If Dialog.Choose() Then
		CatalogName = Dialog.Directory;
		Return True;
	Else
		Return False;
	EndIf;

EndFunction // SelectDirectory()

#EndIf


Function GetStringPartDetachedBySymbols(Val SourceLine, Val SearchSymbol)
	
	SymbolPosition = StrLen(SourceLine);
	While SymbolPosition >= 1 Do
		
		If Mid(SourceLine, SymbolPosition, 1) = SearchSymbol Then
						
			Return Mid(SourceLine, SymbolPosition + 1); 
			
		EndIf;
		
		SymbolPosition = SymbolPosition - 1;	
	EndDo;

	Return "";
  	
EndFunction

// Gets files extension. (number of symbols after last dot)
//
// Parameters
//  FileName     – String, file name
//
// Return Value:
//   String – file extention
//
Function GetFileExtension(Val FileName) Export
	
	Extention = GetStringPartDetachedBySymbols(FileName, ".");
	Return Extention;
	
EndFunction

// Get file name from full file name
//
// Parameters
//  PathToFile     – String, path to file
//
// Return Value:
//   String – File name
//
Function GetFileNameFromFullPath(Val PathToFile) Export
	
	FileName = GetStringPartDetachedBySymbols(PathToFile, "\");
	Return FileName;
	
EndFunction

Function GenerateFileName(Val FileName, Period = Undefined) Export
	
	If Not Period = Undefined Then
		
		FileOnDisk = New File(FileName);
		FileName = FileOnDisk.Path + FileOnDisk.BaseName + " ("+Format(Period, "DF=""yyyy-MM-dd HH-mm-ss""")+")" + FileOnDisk.Extension;
		
	EndIf;
	
	FileName = StrReplace(FileName, "/",  "\");
	FileName = StrReplace(FileName, ":",  "_");
	FileName = StrReplace(FileName, "*",  "_");
	FileName = StrReplace(FileName, "?",  "_");
	FileName = StrReplace(FileName, """", "_");
	FileName = StrReplace(FileName, "<",  "_");
	FileName = StrReplace(FileName, ">",  "_");
	FileName = StrReplace(FileName, "|",  "_");
	
	
	Return FileName;
	
EndFunction

// Get icon index from collection depending on file extension
//
// Parameters
//  FilesExtension – String with file extension
//
// Return value:
//   Number – index of icon
//
Function GetFileIconIndex(FilesExtension) Export

	FilesExtension = Upper(FilesExtension);

	If Find(",1CD,CF,CFU,DT,", "," + FilesExtension + ",") > 0 Then
		Return 1;
	ElsIf "MXL" = FilesExtension Then
		Return 2;
	ElsIf "TXT" = FilesExtension Then
		Return 3;
	ElsIf "EPF" = FilesExtension Then
		Return 4;
	ElsIf Find(",BMP,DIB,RLE,JPG,JPEG,TIF,GIF,PNG,ICO,WMF,EMF,", "," + FilesExtension + ",") > 0 Then
		Return 5;
	ElsIf Find(",HTM,HTML,MHT,", "," + FilesExtension + ",") > 0 Then
		Return 6;
	ElsIf "DOC" = FilesExtension OR "DOCX" = FilesExtension Then
		Return 7;
	ElsIf "XLS" = FilesExtension OR "XLSX" = FilesExtension Then
		Return 8;
	ElsIf "PPT" = FilesExtension Then
		Return 9;
	ElsIf "VSD" = FilesExtension Then
		Return 10;
	ElsIf "MPP" = FilesExtension Then
		Return 11;
	ElsIf "MDB" = FilesExtension Then
		Return 12;
	ElsIf "XML" = FilesExtension Then
		Return 13;
	ElsIf "MSG" = FilesExtension Then
		Return 14;
	ElsIf Find(",RAR,ZIP,ARJ,CAB,", "," + FilesExtension + ",") > 0 Then
		Return 15;
	ElsIf Find(",EXE,COM,,", "," + FilesExtension + ",") > 0 Then
		Return 16;
	ElsIf "BAT" = FilesExtension Then
		Return 17;
	ElsIf "PDF" = FilesExtension Then
		Return 18;	
	Else
		Return 0;
	EndIf;

EndFunction // GetFileIconIndex()


////////////////////////////////////////////////////////////////////////////////////
//// WORKING WITH XML

// returns content Map from XML 
Function GetContentMapFromXML(ReturnedXML) Export
	
	If ReturnedXML = "" Then 
		
		Return Undefined;
		
	EndIf;	
	
	XMLReader = New XMLReader;
	
	XMLReader.SetString(ReturnedXML);
	
	XMLReader.Read(); // Node RetRes
	
	ReceivedMap = New Map();
	ReceivedMap = ReadPlaneXMLNode(ReceivedMap,XMLReader,XMLReader.Name,XMLReader.Name);
	
	XMLReader.Close();
	
	Return ReceivedMap;
	
EndFunction	

Function ReadPlaneXMLNode(ParentMap,XMLReader,AlreadyReadName,EndSectionName) Export
	
	WaitForValue = True;
	
	ElementName = AlreadyReadName;
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			
			If Left(XMLReader.Name,1) = "?"
				And Right(XMLReader.Name,1) = "?" Then
				
				Continue; // XML Notation
				
			EndIf;
			
			If WaitForValue Then // nested
				
				ChildMap = New Map();
				ChildMap = ReadPlaneXMLNode(ChildMap,XMLReader,XMLReader.Name,ElementName);
				NewName = XMLReader.Name;
				Counter = 0;
				
				While ParentMap.Get(NewName+?(Counter>0,String(Counter),"")) <> Undefined Do
				
					Counter = Counter + 1;
					
				EndDo;	
				
				ParentMap.Insert(NewName+?(Counter>0,String(Counter),""),ChildMap);
				
				WaitForValue = False;
				
			Else	
				
				ElementName = XMLReader.Name;
				
				WaitForValue = True;
				
			EndIf;	
			
		EndIf;	
		
		If XMLReader.NodeType = XMLNodeType.Text 
		OR XMLReader.NodeType = XMLNodeType.CDATASection Then
		
			WaitForValue = False;
			ParentMap.Insert(ElementName,XMLReader.Value);
			
		EndIf;	
		
		If XMLReader.NodeType = XMLNodeType.EndElement Then
			
			If WaitForValue Then
				
				WaitForValue = False;
				
			EndIf;	
			
			If XMLReader.Name = EndSectionName Then
				
				Return ParentMap;
				
			EndIf;	
			
		EndIf;	
		
	EndDo;	
	
	Return ParentMap;
	
EndFunction	
