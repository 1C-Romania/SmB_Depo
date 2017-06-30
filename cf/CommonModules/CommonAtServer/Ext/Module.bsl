
#Region WorkingWithObjects

Function GetObjectTitle(Val Object) Export
	ObjectMetadata = Metadata.FindByType(TypeOf(Object));
	ReturnTitle = ?(ObjectMetadata.ObjectPresentation = "", ObjectMetadata.Synonym, ObjectMetadata.ObjectPresentation);
	Return ReturnTitle;
EndFunction

Procedure FillDocumentHeader(DocumentObject) Export 
	
	If TypeOf(DocumentObject) = Type("FormDataStructure") Then
		DocumentMetadata = DocumentObject.Ref.Metadata();
	Else
		DocumentMetadata = DocumentObject.Metadata();
	EndIf;
	
	CurrentUser = DefaultValuesAtServer.GetCurrentUser();
	// Author changing without filling check.
	If IsDocumentAttribute("Author", DocumentMetadata) Then
		DocumentObject.Author = CurrentUser;
	EndIf;
	
	If IsDocumentAttribute("Company", DocumentMetadata) AND ValueIsNotFilled(DocumentObject.Company) Then
		DocumentObject.Company = DefaultValuesAtServer.GetDefaultCompany(CurrentUser);
	EndIf;
	
	If IsDocumentAttribute("Warehouse", DocumentMetadata) AND ValueIsNotFilled(DocumentObject.Warehouse) Then
		DocumentObject.Warehouse = DefaultValuesAtServer.GetDefaultWarehouse(CurrentUser);	
	EndIf;
	
	If IsDocumentAttribute("Department", DocumentMetadata) AND ValueIsNotFilled(DocumentObject.Department) Then
		DocumentObject.Department = DefaultValuesAtServer.GetDefaultDepartment(CurrentUser);
	EndIf;
	
	If IsDocumentAttribute("PriceType", DocumentMetadata) AND ValueIsNotFilled(DocumentObject.PriceType) Then
		DocumentObject.PriceType = DefaultValuesAtServer.GetDefaultPriceType(CurrentUser);
	EndIf;
EndProcedure // FillDocumentHeader()

#EndRegion

#Region GettingTypeDescriptions

Function GetTypeDescription(TypeName = "", Digits = 0, FractionDigits = 0, SetDateFractions = Undefined) Export 
	
	Var TypeDescription;
	
	If TypeOf(TypeName) = Type("String") Then
		
		Array = New Array;
		
		If Not IsBlankString(TypeName) Then
			Array.Add(Type(TypeName));
		EndIf;
		
		If TypeName = "Number" Then
			
			Qualifier = New NumberQualifiers(Digits, FractionDigits);
			TypeDescription = New TypeDescription(Array, Qualifier);
			
		ElsIf TypeName = "String" Then
			
			If FractionDigits = 0 Then
				Qualifier = New StringQualifiers(Digits);
			Else
				Qualifier = New StringQualifiers(Digits, FractionDigits);
			EndIf;
			
			TypeDescription = New TypeDescription(Array, , Qualifier);
			
		ElsIf TypeName = "Date" Then
			
			If SetDateFractions = Undefined Then
				SetDateFractions = DateFractions.Date;
			EndIf;
			
			Qualifier = New DateQualifiers(SetDateFractions);
			TypeDescription = New TypeDescription(Array, , , Qualifier);
			
		Else
			
			TypeDescription = New TypeDescription(Array);
			
		EndIf;
		
	ElsIf TypeOf(TypeName) = Type("TypeDescription") Then
		
		TypeDescription = TypeName;
		
	EndIf;
	
	Return TypeDescription;
	
EndFunction // GetTypeDescription()

Function GetStringTypeDescription(StringLenth) Export 
	
	Return GetTypeDescription("String", StringLenth);
	
EndFunction // GetStringTypeDescription()

Function GetBooleanTypeDescription() Export 
	
	Return GetTypeDescription("Boolean");
	
EndFunction // GetBooleanTypeDescription()

//Procedure SetIsThisServerInfobaseConstantConstant() Export
//	
//	IsThisServerInfobase = NOT Common.DetectIsThisInfobaseIsLocal();
//	ConstantValue = Constants.IsThisServerInfobaseConstant.Get();
//	If ConstantValue <> IsThisServerInfobase Then
//		SetPrivilegedMode(True);
//		Constants.IsThisServerInfobaseConstant.Set(IsThisServerInfobase);
//		SetPrivilegedMode(False);
//	EndIf;	
//	
//EndProcedure

Procedure SetLongActionsDebugConstant() Export
	
	If 
		// Jack 27.06.2017
		//NOT Constants.IsThisServerInfobaseConstant.Get() AND 
		NOT Constants.LongActionsDebugMode.Get() Then
		
		// need to turn on debug mode
		Constants.LongActionsDebugMode.Set(True);
		
	EndIf;	
	
EndProcedure	

#EndRegion

//Procedure SetBookkeepingFunctionalityConstant() Export
//	
//	IsBookkeepingRegister = True;
//	ConstantValue = Constants.BookkeepingFunctionalityConstant.Get();
//	If ConstantValue <> IsBookkeepingRegister Then
//		SetPrivilegedMode(True);
//		Constants.BookkeepingFunctionalityConstant.Set(IsBookkeepingRegister);
//		SetPrivilegedMode(False);
//	EndIf;	
//	
//EndProcedure

Function GetSearchSubStringsArray(FastFilter)
	
	PrevSpacePos = 0;
	SearchStringsArray = New Array;
	For i = 1 to StrLen(FastFilter) Do
		If Mid(FastFilter, i, 1) = " " Then
			If i - PrevSpacePos > 1 Then
				SearchStringsArray.Add(Mid(FastFilter, PrevSpacePos + 1, i - PrevSpacePos - 1));
			EndIf;
			PrevSpacePos = i;
		EndIf;
	EndDo;
	
	If i - PrevSpacePos > 1 Then
		SearchStringsArray.Add(Mid(FastFilter, PrevSpacePos + 1, i - PrevSpacePos - 1));
	EndIf;
	
	Return SearchStringsArray;
	
EndFunction	

Function GetObjectFromXML(String,ObjectType, XMLSerializer = False) Export
	
	XMLReader = New XMLReader();
	XMLReader.SetString(String);
	If XMLSerializer Then
		Return ReadXML(XMLReader,ObjectType);
	Else
		Return XDTOSerializer.ReadXML(XMLReader,ObjectType);
	EndIf;
	
EndFunction	

// Finding first tabular part row, that agree with filter.
//
// Returning values:
//  Tabular part row - finded row,
//  Undefined        - if the row was not founded.
//
Function FindTabularPartRow(TabularPart, RowFilterStructure) Export 
	
	RowsArray = TabularPart.FindRows(RowFilterStructure);
	
	If RowsArray.Count() = 0 Then
		Return Undefined;
	Else
		Return RowsArray[0];
	EndIf;
	
EndFunction // FindTabularPartRow()

//Function IsFullTextSearchSpecialSymbolInWord(Word) Export
//	
//	SpecialSymbolsArray = New Array();
//	SpecialSymbolsArray.Add(" AND ");
//	SpecialSymbolsArray.Add(" OR ");
//	SpecialSymbolsArray.Add(" NOT ");
//	SpecialSymbolsArray.Add(" NEAR/");
//	SpecialSymbolsArray.Add("#");
//	SpecialSymbolsArray.Add("""");
//	SpecialSymbolsArray.Add("!");
//	SpecialSymbolsArray.Add("*");
//	SpecialSymbolsArray.Add("(");
//	SpecialSymbolsArray.Add(")");
//	SpecialSymbolsArray.Add("|");
//	SpecialSymbolsArray.Add("-)");
//	SpecialSymbolsArray.Add("~");
//	SpecialSymbolsArray.Add("-");
//	
//	ReturnValue = False;
//	
//	For Each SpecialSymbol In SpecialSymbolsArray Do
//		
//		If Find(Word,SpecialSymbol)>0 Then
//			Return True;
//		EndIf;	
//		
//	EndDo;	
//	
//	WasException = False;
//	Try
//		Num = Number(Word);
//	Except
//		WasException = True;
//	EndTry;
//	
//	If Not WasException Then
//		Return True;
//	EndIf;	
//	
//	Return ReturnValue;
//	
//EndFunction	

Function GetUserSettingsValue(Val pSetting = "", Val User = Undefined) Export
   // add by Jack 28.03.2017 begin
   Setting=pSetting;
   If Setting="Company" Then
        Setting="MainCompany"
    EndIf;
    // add by Jack 28.03.2017 end

	
	If Not Setting = "" Then
		If TypeOf(Setting) = Type("String") Then
			UserSetting = ChartsOfCharacteristicTypes.UserSettings[Setting];
		ElsIf TypeOf(Setting) = TypeOf(ChartsOfCharacteristicTypes.UserSettings.EmptyRef()) Then
			UserSetting = Setting;
		Else
			Raise NStr("en=""Wrong parameter type in function GetUserSettingsValue(). Parameter 1."";pl=""Niepoprawny typ parametru dla funkcji GetUserSettingsValue(). Parametr 1.""");
		EndIf;
	EndIf;
	If User = Undefined Then
		User = SessionParameters.CurrentUser;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	InformReg.Value,
	             |	InformReg.Setting
	             |FROM
	             |	InformationRegister.UserSettings AS InformReg
	             |WHERE
	             |	InformReg.User = &User";
	If Not UserSetting = "" And Not UserSetting = Undefined Then
		Query.Text = Query.Text + " 
		             |	AND InformReg.Setting = &Setting";
		Query.SetParameter("Setting", UserSetting);
	EndIf;
	
	Query.SetParameter("User",    User);
	
	Selection = Query.Execute().Select();
	
	If Setting = "" Then
		
		ReturnArray = New Array;
		
		While Selection.Next() Do
			ReturnArray.Add(New Structure("Setting, Value", Selection.Setting, Selection.Value));
		EndDo;
		
		Return ReturnArray;
	EndIf;
	
	EmptyValue = UserSetting.ValueType.AdjustValue();
	
	If Selection.Count() = 0 Then
		Return EmptyValue;
	ElsIf Selection.Next() Then
		If ValueIsNotFilled(Selection.Value) Then
			Return EmptyValue;
		Else
			Return Selection.Value;
		EndIf;
	Else
		Return EmptyValue;
	EndIf;
	
EndFunction // GetUserSettingsValue()

Function AddClientParametersOnStartup(Parameters)
	Parameters.Insert("SeparationIsSwitchOn", False);
	
	Parameters.Insert("AvailableUseDataSeparation", False);
	
	Parameters.Insert("IsSeparationConfiguration", False);
	Parameters.Insert("AvailableForPlatformUpdate", False);
	
	Parameters.Insert("SubsystemNames", "");
	
	Parameters.Insert("MinimumRequiredPlatformVersion", "8.3.6.2237");
	Parameters.Insert("WorkingInProgramIsForbidden", False);
	
	Return False;
EndFunction

Procedure HideDesktopAtSystemStartup(Hide = True) Export
	
	SetPrivilegedMode(True);
	
	CurrentParameters = New Map(SessionParameters.ClientParametersAtServer);
	
	If Hide = True Then
		CurrentParameters.Insert("HideDesktopAtSystemStartup", True);
		
	ElsIf CurrentParameters.Get("HideDesktopAtSystemStartup") <> Undefined Then
		CurrentParameters.Delete("HideDesktopAtSystemStartup");
	EndIf;
	
	SessionParameters.ClientParametersAtServer = New FixedMap(CurrentParameters);
	
EndProcedure

Procedure SaveTempParameters(Parameters)
	
	Parameters.Insert("NameTempParameters", New Array);
	
	For Each KeyAndValue In Parameters Do
		Parameters.NameTempParameters.Add(KeyAndValue.Key);
	EndDo;
	
EndProcedure

Procedure ExecuteSimpleQuery(Val QueryText, Val QueryParametersSet, Val StorageAddress) Export
	
	Query = New Query(QueryText);
	
	For Each KeyAndValue In QueryParametersSet Do	
		Query.SetParameter(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	PutToTempStorage(Query.Execute(),StorageAddress);
	
EndProcedure	

Function StartupClientParameters(Val Parameters) Export

	PrivilegedModeSetAtStartup = PrivilegedMode();
	// Jack 27.06.2017
	//SetBookkeepingFunctionalityConstant();
	
	SetPrivilegedMode(True);
	If SessionParameters.ClientParametersAtServer.Count() = 0 Then
		// first server-call from client on Startup
		ClientParameters = New Map;

		ClientParameters.Insert("LaunchParameter", Parameters.LaunchParameter);
		ClientParameters.Insert("InfoBaseConnectionString", Parameters.InfoBaseConnectionString);
		ClientParameters.Insert("PrivilegedModeSetAtStartup", PrivilegedModeSetAtStartup);
		ClientParameters.Insert("IsWebClient", Parameters.IsWebClient);
		ClientParameters.Insert("IsWebClientMacOS", Parameters.IsWebClientMacOS);
		ClientParameters.Insert("IsLinuxClient", Parameters.IsLinuxClient);
		ClientParameters.Insert("IsMacOSClient", Parameters.IsMacOSClient);
		ClientParameters.Insert("mComputerName", Parameters.mComputerName);
		
		SessionParameters.ClientParametersAtServer = New FixedMap(ClientParameters);

	EndIf;
	SetPrivilegedMode(False);
	
	// Jack 27.06.2017
	//Parameters.Insert("VersionNumber", Constants.DatabaseVersion.Get());
	Parameters.Insert("MetadataVersion", Metadata.Version);
	Parameters.Insert("NeedUpdateInfoBase", Parameters.VersionNumber <> Parameters.MetadataVersion);
	       
	Parameters.Insert("AccessRightExclusiveMode", AccessRight("ExclusiveMode", Metadata));
	 // Jack 27.06.2017
	//Parameters.Insert("AccessRightUpdateInfoBase", AccessRight("Use", Metadata.DataProcessors.UpdateInfoBase) And AccessRight("View", Metadata.DataProcessors.UpdateInfoBase));
	//Parameters.Insert("RequestForInfobaseClosingLocal", True);
	Parameters.Insert("IsExclusiveMode", False);
	
	// check permissions
	// Jack 27.06.2017
	//If NOT AccessRight("ExclusiveMode", Metadata) 
	// OR NOT AccessRight("Use", Metadata.DataProcessors.UpdateInfoBase) 
	// OR NOT AccessRight("View", Metadata.DataProcessors.UpdateInfoBase) Then
	//	Parameters.RequestForInfobaseClosingLocal = False;
	//ElsIf Parameters.NeedUpdateInfoBase Then
	//	// try to go to exclusive mode
	//	Try
	//		SetExclusiveMode(True);
	//		Parameters.IsExclusiveMode = True;
	//	Except
	//		Parameters.RequestForInfobaseClosingLocal = False;
	//	EndTry;
	//EndIf;

	//Parameters.Insert("RequestForInfobaseClosing", CommonAtServer.GetUserSettingsValue("RequestForInfobaseClosing"));
	Parameters.Insert("CustomCaption", CommonAtServer.GetUserSettingsValue("CustomCaption"));
	// Jack 27.06.2017
	//Parameters.Insert("NationalCurrency", Constants.NationalCurrency.Get());
	Parameters.Insert("CurrentUser", SessionParameters.CurrentUser);	
	Parameters.Insert("UserSettingsValue", GetUserSettingsValue()); 
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IsBookkeepingAvailable", SessionParameters.IsBookkeepingAvailable);
	
	Parameters.Insert("SessionParameters", AdditionalParameters);
	
	// Jack 27.06.2017
	//Query = New Query;
	//
	//Query.Text = "SELECT
	//|	Tradeware.Identifier
	//|FROM
	//|	InformationRegister.Tradeware AS Tradeware
	//|WHERE
	//|	Tradeware.Computer = &ComputerName
	//|	AND Tradeware.Model.Type = &Type";
	//
	//Query.SetParameter("ComputerName", Parameters.mComputerName);
	//Query.SetParameter("Type", Enums.TradewareTypes.FiscalPrinter);
	//
	//Result = Query.Execute();
	//Selection = Result.Select();
	//If Selection.Next() Then
	//	Parameters.Insert("IdentifierFiscalPrinter", Selection.Identifier);
	//Else
	//	Parameters.Insert("IdentifierFiscalPrinter", Undefined);
	//EndIf;
	
	
	Return Parameters;
EndFunction

//Procedure PerformInfoBaseUpdate(Parameters) Export
//	DataProcessors.UpdateInfoBase.Create().Update();
//	If Parameters.IsExclusiveMode Then
//		SetExclusiveMode(False);
//		Parameters.IsExclusiveMode = False;
//	EndIf;
//	Parameters.VersionNumber = Constants.DatabaseVersion.Get();
//	Parameters.MetadataVersion = Metadata.Version;
//	Parameters.NeedUpdateInfoBase = Parameters.VersionNumber <> Parameters.MetadataVersion;
//EndProcedure

//Function GetInfoBaseUpdateProcessors() Export
//	Return DataProcessors.UpdateInfoBase.GetUpdateProcessors()
//EndFunction

//Function PutCompanyLogoIntoTempStorage(Company,FormUUID) Export
//	
//	RecordSet = InformationRegisters.CompanyLogo.CreateRecordSet();
//	RecordSet.Filter.Company.Set(Company);
//	RecordSet.Read();
//	
//	If RecordSet.Count()>0 Then
//		
//		Record = RecordSet[0];
//		CompanyLogo = Record.Logo.Get();
//		
//		If TypeOf(CompanyLogo) = Type("BinaryData") Then
//			Return PutToTempStorage(CompanyLogo,FormUUID);
//		Else
//			Return "";
//		EndIf;
//	Else	
//		Return "";
//	EndIf;
//	
//EndFunction	

Function GetNameFile(FileName) Export
	TempNameFile = StrReplace(FileName, "/", "\");
	While Find(TempNameFile, "\") > 0 Do
		TempNameFile = Right(TempNameFile, StrLen(TempNameFile) - Find(TempNameFile, "\"));
	EndDo;
	Return TempNameFile;
EndFunction

//Function return Array of full names of files
//
//FileStruct - Structure:
//BinaryData - Binary data for temp file. Property is required
//FileName - file name or Extension (name without "."). Property is optional  
//Password - Password For ZIP-File. If file extension is ZIP. Property is optional
//Array.Count() = 1 if FileName isn't ZIP-file
Function WriteFiles(FileStruct) Export
	ArrayFileNames = New Array;
	
	FileName = Undefined;

	If FileStruct.Property("FileName", FileName) Then
		If Find(FileName, ".") = 0 Then
			FullTempFileName = GetTempFileName(FileName);
		Else
			FullTempFileName = AdditionalInformationRepository.GetDirectoryName() + "\" + FileName;
		EndIf;
	Else
		FullTempFileName = GetTempFileName();
	EndIf;
	
	FileStruct.BinaryData.Write(FullTempFileName);
	
	If Find(Upper(FullTempFileName), ".ZIP") = 0 Then
		 ArrayFileNames.Add(FullTempFileName);
	Else
		Password = Undefined;
		If FileStruct.Property("Password", Password) Then
			ZipFileReader = New ZipFileReader(FullTempFileName, Password);
		Else
			ZipFileReader = New ZipFileReader(FullTempFileName);
		EndIf;
		For Each ItemFile In ZipFileReader.Items Do
			ArrayFileNames.Add(AdditionalInformationRepository.GetDirectoryName() + "\" + ItemFile.FullName);
		EndDo;
		ZipFileReader.ExtractAll(AdditionalInformationRepository.GetDirectoryName() + "\");
		
		DeleteFiles(FullTempFileName);
	EndIf;
	
	Return ArrayFileNames;
	
EndFunction

//Return Array whith Structure FileName | SpreadsheetDocument (Reading from MXL, XLS, XLSX, or ODS)
//Array.Count() = 1 if FileName isn't ZIP-file
//Array.Count() = 0 if FileName havn't MXL, XLS, XLSX, or ODS in name
//
//FileStruct - Structure:
//BinaryData - Binary data for temp file. Property is required
//FileName - file name or Extension (name without "."). Property is optional  
//Password - Password For ZIP-File. If file extension is ZIP. Property is optional
Function GetSpreadsheetDocument(FileStruct) Export
	ReturnResult = New Array;
	
	PermissibleExtensions = New Array;
	PermissibleExtensions.Add("MXL");
	PermissibleExtensions.Add("XLS");
	PermissibleExtensions.Add("XLSX");
	PermissibleExtensions.Add("ODS");
	
	TempFiles = WriteFiles(FileStruct);
	For Each File In TempFiles Do
		IsPermissibleExtensions = False;
		For Each Extension In PermissibleExtensions  Do
			If Not Find(Upper(File), "." + Extension) = 0 Then
				IsPermissibleExtensions = True;
				Break;
			EndIf;
		EndDo;
		
		If Not IsPermissibleExtensions Then
			Continue;
		EndIf;
		
		SpDoc = New SpreadsheetDocument;
		Try
			SpDoc.Read(File, SpreadsheetDocumentValuesReadingMode.Value);
		Except
			Continue;
		EndTry;
		
		ReturnResult.Add(New Structure("FileName, SpreadsheetDocument", GetNameFile(File), SpDoc));
		DeleteFiles(File);
	EndDo;
	
	Return ReturnResult;
EndFunction

//Function GetDataProcessor(FileStruct) Export
//	
//	ReturnResult = New Structure("FileName, FullFileName, ExternalDataProcessor, BinaryData");
//	
//	PermissibleExtensions = New Array;
//	PermissibleExtensions.Add("EPF");
//	
//	TempFiles = WriteFiles(FileStruct);
//	For Each File In TempFiles Do
//		IsPermissibleExtensions = False;
//		For Each Extension In PermissibleExtensions  Do
//			If Not Find(Upper(File), "." + Extension) = 0 Then
//				IsPermissibleExtensions = True;
//				Break;
//			EndIf;
//		EndDo;
//		
//		ReturnResult.FullFileName = File;
//		ReturnResult.FileName = GetNameFile(File);
//		SetPrivilegedMode(True);
//		ReturnResult.ExternalDataProcessor = ExternalDataProcessors.Create(File);
//		ReturnResult.BinaryData = New BinaryData(File);
//		SetPrivilegedMode(False);
//		If IsPermissibleExtensions Then
//			Break;
//		EndIf;
//	EndDo;
//	
//	Return ReturnResult;

//EndFunction

//Function ExternalDataProcessorsConnect(Address)
//	
//	Return ExternalDataProcessors.Connect(Address);

//EndFunction

//Function GetDataProcessorFromStorage(RefDataProcessor, FullInfo = False) Export
//	DataProcessorID = RefDataProcessor;
//	ReturnResult = SessionParameters.ClientParametersAtServer.Get(DataProcessorID);
//	DataProcessor = Undefined;
//	If Not ReturnResult = Undefined Then
//		if GetFromTempStorage(ReturnResult.DataProcessorAddress).DataProcessor = Undefined Then
//			ReturnResult = Undefined
//		EndIf;
//	EndIF;
//	If ReturnResult = Undefined Then
//		
//		If CurrentRunMode() = ClientRunMode.ManagedApplication Then 
//			WriteInFile = False;
//		Else
//			WriteInFile = True;
//		EndIf;
//		
//		ReturnResult = New Structure("FileName, FullFileName, DataProcessorAddress, DataProcessorName");
//		If WriteInFile Then
//			PermissibleExtensions = New Array;
//			PermissibleExtensions.Add("EPF");
//			
//			TempFiles = WriteFiles(New Structure("BinaryData, FileName", RefDataProcessor.Processor.Get(), "epf"));
//			For Each File In TempFiles Do
//				IsPermissibleExtensions = False;
//				For Each Extension In PermissibleExtensions  Do
//					If Not Find(Upper(File), "." + Extension) = 0 Then
//						IsPermissibleExtensions = True;
//						Break;
//					EndIf;
//				EndDo;
//				
//				ReturnResult.FullFileName = File;
//				ReturnResult.FileName = GetNameFile(File);
//				SetPrivilegedMode(True);
//				
//				DataProcessor = ExternalDataProcessors.Create(ReturnResult.FullFileName);
//				ReturnResult.DataProcessorAddress = PutToTempStorage(New Structure("DataProcessor", DataProcessor), New UUID);
//				
//				SetPrivilegedMode(False);
//				If IsPermissibleExtensions Then
//					Break;
//				EndIf;
//			EndDo;
//		Else
//			tpmDataProcessorAddress = PutToTempStorage(RefDataProcessor.Processor.Get());
//			ReturnResult.DataProcessorName = ExternalDataProcessorsConnect(tpmDataProcessorAddress);
//			DataProcessor = ExternalDataProcessors.Create(ReturnResult.DataProcessorName);
//			DeleteFromTempStorage(tpmDataProcessorAddress);
//			ReturnResult.DataProcessorAddress = PutToTempStorage(New Structure("DataProcessor", DataProcessor), New UUID);
//		EndIf;
//		
//		TempMap = New Map(SessionParameters.ClientParametersAtServer);
//		TempMap.Insert(DataProcessorID, New FixedStructure(ReturnResult));
//		SessionParameters.ClientParametersAtServer = New FixedMap(TempMap);
//	Else
//		tmpReturnResult = New Structure;
//		For Each ItemReturnResult In ReturnResult Do
//			tmpReturnResult.Insert(ItemReturnResult.Key, ItemReturnResult.Value);
//		EndDo;
//		ReturnResult = tmpReturnResult;
//	EndIf;
//	If FullInfo Then
//		If DataProcessor = Undefined Then
//			ReturnResult.Insert("DataProcessor", GetFromTempStorage(ReturnResult.DataProcessorAddress).DataProcessor);
//		Else
//			ReturnResult.Insert("DataProcessor", DataProcessor);
//		EndIf;
//		
//		Return ReturnResult;
//	Else
//		If DataProcessor = Undefined Then
//			Return GetFromTempStorage(ReturnResult.DataProcessorAddress).DataProcessor;
//		Else
//			Return DataProcessor;
//		EndIf;
//	EndIf;

//EndFunction

//Procedure DeleteDataProcessorFromStorage()
//	For Each Parameter In SessionParameters.ClientParametersAtServer Do
//		If TypeOf(Parameter.Key) = Type("CatalogRef.BankServiceProcessors") Then
//			 DeleteFromTempStorage(Parameter.Value.DataProcessorAddress);
//			 DeleteFiles(Parameter.Value.FullFileName);
//		EndIf;
//	EndDo;
//EndProcedure

//Procedure BeforeExit() Export
//	
//	DeleteDataProcessorFromStorage();
//	
//EndProcedure

//Function GetPaymentDate(InitialDate, PaymentTerm) Export 
//	
//	If InitialDate = '00010101' Then
//		Return InitialDate;
//	EndIf;
//	
//	PaymentDate = BegOfDay(InitialDate);
//	
//	If TypeOf(PaymentTerm) <> Type("CatalogObject.PaymentTerms") And PaymentTerm.Ref.IsEmpty() Then
//		Return PaymentDate;
//	EndIf;
//	
//	If PaymentTerm.PaymentDay = Enums.PaymentDays.InvoiceDate Then
//		
//		// Nothing to do.
//		
//	ElsIf PaymentTerm.PaymentDay = Enums.PaymentDays.EndOfWeek Then
//		
//		PaymentDate = EndOfWeek(PaymentDate);
//		
//	ElsIf PaymentTerm.PaymentDay = Enums.PaymentDays.EndOfMonth Then
//		
//		PaymentDate = EndOfMonth(PaymentDate);
//		
//	ElsIf PaymentTerm.PaymentDay = Enums.PaymentDays.EndOfQuarter Then
//		
//		PaymentDate = EndOfQuarter(PaymentDate);
//		
//	ElsIf PaymentTerm.PaymentDay = Enums.PaymentDays.EndOfYear Then
//		
//		PaymentDate = EndOfYear(PaymentDate);
//		
//	EndIf;
//	
//	MonthToAdd = PaymentTerm.Months*PaymentTerm.MonthsSign; 
//	PaymentDate = AddMonth(PaymentDate, MonthToAdd);
//	If (PaymentTerm.PaymentDay = Enums.PaymentDays.EndOfMonth
//		OR PaymentTerm.PaymentDay = Enums.PaymentDays.EndOfQuarter)
//		AND MonthToAdd<>0 Then
//		PaymentDate = EndOfMonth(PaymentDate);
//	EndIf;	
//	PaymentDate = BegOfDay(PaymentDate) + PaymentTerm.Days*PaymentTerm.DaysSign*60*60*24;
//	
//	Return PaymentDate;
//	
//EndFunction // GetPaymentDay()

// Return currency exchange rate on date
//
// Parameters:
//  Currency     - Currency (catalog "Currencies" item)
//  RateDate  - Date, on which will be get following exchange rate
//
// Return value: 
// 	Exchange rate record with exchange rate, table number
//

Function GetExchangeRateRecord(Currency, RateDate) Export 
	
	Query = New Query;
	Query.Text = "SELECT
	             |	CurrencyExchangeRatesSliceLast.Period,
	             |	CurrencyExchangeRatesSliceLast.ExchangeRate,
	             |	CurrencyExchangeRatesSliceLast.NBPTableNumber
	             |FROM
	             |	InformationRegister.CurrencyExchangeRates.SliceLast(&RateDate, Currency = &Currency) AS CurrencyExchangeRatesSliceLast";
	Query.SetParameter("Currency",Currency);
	Query.SetParameter("RateDate",RateDate);
	QueryResult = Query.Execute();
	
	ReturnStructure = New Structure("Period, ExchangeRate, NBPTableNumber");
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		ReturnStructure.Period = Selection.Period;
		ReturnStructure.ExchangeRate = Selection.ExchangeRate;
		ReturnStructure.NBPTableNumber = Selection.NBPTableNumber;
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction // GetExchangeRate()

// Return currency exchange rate on date
//
// Parameters:
//  Currency     - Currency (catalog "Currencies" item)
//  RateDate  - Date, on which will be get following exchange rate
//
// Return value: 
// 	Exchange rate
//

Function GetExchangeRate(Currency, RateDate) Export 
	
	// by Jack 03.04.2017
    // Return CommonAtServer.GetExchangeRate(Currency,RateDate);
    Return 1;

	
EndFunction // GetExchangeRate()


Function GetDocumentExchangeRateDate(DocumentObject, UseAccountingPolicyExchangeRateDateForCalculatingSalesAndPurchase = False,AlternateDate = Undefined) Export
	
	If AlternateDate <> Undefined AND AlternateDate <> '00010101' Then
		InitialDate = AlternateDate;
	Else	
		InitialDate = ?(DocumentObject.Date = '00010101', CurrentDate(), DocumentObject.Date);
	EndIf;	
	
	// Jack 27.06.2017
	// to do
	//If UseAccountingPolicyExchangeRateDateForCalculatingSalesAndPurchase Then
	//	
	//	ExchangeRateDatePolicy = InformationRegisters.AccountingPolicyGeneral.GetLast(InitialDate, New Structure("Company", DocumentObject.Company)).ExchangeRateForCalculatingSalesAndPurchase;
	//	
	//	If ExchangeRateDatePolicy = Enums.AccountingPolicy_ExchangeRateForCalculatingSalesAndPurchase.DayBeforeDocumentsDate Then
	//		InitialDate = EndOfDay(InitialDate - 60*60*24);
	//	Else
	//		// In all other cases leave initial date as is.
	//	EndIf;
	//	
	//EndIf;
		
	Return InitialDate;
	
EndFunction // GetDocumentExchangeRateDate()


Function GetExchangeRateDifferencePolicy( Date, Company, Sign, CarriedOut, Group ) Export
	SignForFilter = ?(Sign < 0, Enums.ExchangeRateDifferenceSign.Negative, Enums.ExchangeRateDifferenceSign.Positive);
	GroupForFilter = ?(Group, Enums.ExchangeRateDifferenceGroup.InGroup, Enums.ExchangeRateDifferenceGroup.OutsideGroup);
	TmpFilter = New Structure("Company, Sign, CarriedOut, GroupKind", Company, SignForFilter, CarriedOut, GroupForFilter );
	AccountingPolicy = InformationRegisters.BookkeepingAccountingPolicyExchangeRateDifference.SliceLast(Date, TmpFilter);
	
	// no group
	If AccountingPolicy.Count() = 0 And Group <> Enums.ExchangeRateDifferenceGroup.NoConcern Then
		TmpFilter.GroupKind = Enums.ExchangeRateDifferenceGroup.NoConcern;
		AccountingPolicy = InformationRegisters.BookkeepingAccountingPolicyExchangeRateDifference.SliceLast(Date, TmpFilter);
	EndIf;
	
	// fetch first row
	If AccountingPolicy.Count() > 0 Then
		Return AccountingPolicy.Get(0);
	Else
		Return Undefined;
	EndIf;
EndFunction

Function IsDocumentAttribute(AttributeName, DocumentMetadata) Export 
	
	IsAttribute = Not (DocumentMetadata.Attributes.Find(AttributeName) = Undefined);
	
	If Not IsAttribute Then
		CommonAttribute = Metadata.CommonAttributes.Find(AttributeName);
		If Not CommonAttribute = Undefined Then
			AutoUse = CommonAttribute.AutoUse = Metadata.ObjectProperties.CommonAttributeUse.Use;
			IsAttribute = (CommonAttribute.Content.Find(DocumentMetadata).Use = Metadata.ObjectProperties.CommonAttributeUse.Use)
				Or (AutoUse And CommonAttribute.Content.Find(DocumentMetadata).Use = Metadata.ObjectProperties.CommonAttributeUse.Auto);
		EndIf;
	EndIf;     
	
	Return IsAttribute;
	
EndFunction // IsDocumentAttribute()


Function GetEnumNameByValue(EnumValue) Export
	
	If ValueIsFilled(EnumValue) Then
		
		EnumName = EnumValue.Metadata().Name;
		Return Metadata.Enums[EnumName].EnumValues[Enums[EnumName].IndexOf(EnumValue)].Name;
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction // GetEnumNameByValue()


Function GetNationalAmount(Amount, Currency, ExchangeRate) Export
	
	If ValueIsNotFilled(Currency) Or Currency = Constants.NationalCurrency.Get() Then
		Return Amount;
	Else
		Return Round(Amount*ExchangeRate, 2);
	EndIf;
	
EndFunction


//Procedure CreateNewInternalDocument(Control, Text, Value, StandardProcessing, mSupplierTyping, mSupplierTypingText, mLastValueOfSupplierTyping, ThisForm, Modified, CatalogName,TabularPartName = "SettlementDocuments",Owner = Undefined,OmitQuestionOnNewCreation = False) Export
//	
//	StandardProcessing = False;
//	
//	If TypeOf(Control.Value) <> Type("String") Then
//		
//		If NOT OmitQuestionOnNewCreation Then
//			If CatalogName = "EmployeeInternalDocuments" Then
//				QueryText = NStr("en = 'Employee''s internal document not found. Add new document?'; pl = 'Nie znaleziono wewnętrznego dokumentu pracownika. Dodać nowy dokument?'");
//			ElsIf CatalogName = "CustomerInternalDocuments"
//				OR CatalogName = "SupplierInternalDocuments" Then
//				QueryText = NStr("en=""Partner's internal document not found. Add new document?"";pl='Nie znaleziono wewnętrznego dokumentu kontrahenta. Dodać nowy dokument?'");
//			Else
//				Return;
//			EndIf;	
//			
//		EndIf;
//		
//		NewInternalDocument = Catalogs[CatalogName].CreateItem();
//		NewInternalDocumentForm = NewInternalDocument.GetForm(,ThisForm,ThisForm);
//		
//		CurrentRow = ThisForm.Controls[TabularPartName].CurrentRow;
//		If CatalogName = "EmployeeInternalDocuments" Then
//			NewInternalDocument.Owner = ?(Owner = Undefined,CurrentRow.Employee,Owner);
//		Else
//			NewInternalDocument.Owner = ?(Owner = Undefined,CurrentRow.Partner,Owner);
//		EndIf;	
//		
//		DocumentMetadata = ThisForm.Ref.Metadata();
//		If IsDocumentAttribute("InitialDocumentDate",DocumentMetadata) Then
//			NewInternalDocument.InitialDocumentDate = ThisForm.InitialDocumentDate;
//		Else
//			NewInternalDocument.InitialDocumentDate = ThisForm.Date;
//		EndIf;
//		If IsDocumentAttribute("InitialDocumentNumber",DocumentMetadata) Then
//			NewInternalDocument.InitialDocumentNumber = ThisForm.InitialDocumentNumber;
//		Else
//			NewInternalDocument.InitialDocumentNumber = Text;
//		EndIf;	
//		NewInternalDocument.Description = Text;
//		NewInternalDocument.Currency = ThisForm.SettlementCurrency;
//		If IsDocumentAttribute("SettlementExchangeRate",DocumentMetadata) Then
//			NewInternalDocument.ExchangeRate = ThisForm.SettlementExchangeRate;
//		Else
//			NewInternalDocument.ExchangeRate = GetExchangeRate(NewInternalDocument.Currency, NewInternalDocument.InitialDocumentDate);
//		EndIf;
//		
//		NewInternalDocumentForm.DoModal();
//		
//		Value = NewInternalDocument.Ref;
//		Modified = True;
//		
//	Else
//		
//		Value = Text;
//		
//	EndIf;
//	
//EndProcedure	


//Function GetCustomerSpecialAttributes(Customer) Export
//	
//	Structure = New Structure();
//	If Customer.CustomerType = Enums.CustomerTypes.Independent Then
//		
//		Structure.Insert("AccountingGroup",Customer.AccountingGroup);
//		Structure.Insert("AmountType",Customer.AmountType);
//		Structure.Insert("Currency",Customer.Currency);
//		Structure.Insert("VATNumber",Customer.VATNumber);
//		
//	Else
//		
//		Structure.Insert("AccountingGroup",Customer.HeadOffice.AccountingGroup);
//		Structure.Insert("AmountType",Customer.HeadOffice.AmountType);
//		Structure.Insert("Currency",Customer.HeadOffice.Currency);
//		Structure.Insert("VATNumber",Customer.HeadOffice.VATNumber);
//		
//	EndIf;	
//	
//	Return Structure;
//	
//EndFunction	

//// Get list of available UoM's for item

//Function GetItemsUnitsOfMeasureValueList(Item) Export 
//	
//	ValueList = New ValueList;
//	
//	If ValueIsNotFilled(Item) Then
//		Return ValueList;
//	EndIf;	
//	
//	Query = New Query;
//	Query.Text = "SELECT
//	             |	ItemsUnitsOfMeasure.UnitOfMeasure,
//	             |	ItemsUnitsOfMeasure.Quantity,
//	             |	PRESENTATION(ItemsUnitsOfMeasure.UnitOfMeasure),
//	             |	PRESENTATION(ItemsUnitsOfMeasure.Ref.BaseUnitOfMeasure)
//	             |FROM
//	             |	Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasure
//	             |WHERE
//	             |	ItemsUnitsOfMeasure.Ref = &Item
//	             |
//	             |ORDER BY
//	             |	ItemsUnitsOfMeasure.LineNumber";
//	
//	Query.SetParameter("Item", Item);
//	
//	Selection = Query.Execute().Select();
//	
//	While Selection.Next() Do
//		If ValueList.FindByValue(Selection.UnitOfMeasure) = Undefined Then
//			ValueList.Add(Selection.UnitOfMeasure,"" + Selection.UnitOfMeasurePresentation + " ("+Selection.Quantity+" "+Selection.BaseUnitOfMeasurePresentation+")");
//		EndIf;	
//	EndDo;
//	
//	Return ValueList;
//	
//EndFunction // GetItemsUnitsOfMeasureValueList()


//Function IsCreditCardInSystem(CardNumber, PaymentMetodResult = Undefined) Export
//	
//	If IsBlankString(CardNumber) Then
//		Return False;
//	EndIf;	
//	
//	Query = New Query;
//	Query.Text = "SELECT TOP 1
//	             |	PaymentMetodDetails.PaymentMetod.Ref AS Ref
//	             |FROM
//	             |	InformationRegister.PaymentMetodDetails AS PaymentMetodDetails
//	             |WHERE
//	             |	PaymentMetodDetails.PaymentMetod.PaymentCardNumber = &PaymentCardNumber";
//	
//	Query.SetParameter("PaymentCardNumber", CardNumber);
//	
//	Result = Query.Execute();
//	
//	If Result.IsEmpty() Then
//		
//		Return False;
//		
//	Else
//		
//		Selection = Result.Select();
//		
//		While Selection.Next() Do
//			
//			PaymentMetodResult = Selection.Ref;
//			Return True;
//			
//		EndDo;
//	
//	EndIf;
//	
//	Return False;
//	
//EndFunction

//////////////////////////////////COMMON/////////////////////////////////////////////

Function GetGeneratedByText(LanguageCode = "") Export
	
	Return NStr("en = 'Generated by 1C:Enterpise 8.'; pl = 'Wygenerowany przez 1C:Enterprise 8.'; ru = 'Сформировано с помощью 1С:Предприятие 8.'", LanguageCode) + " " + NStr("en = 'Configuration'; pl = 'Konfiguracja'; ru = 'Конфигурация'", LanguageCode) + " " + Metadata.DetailedInformation;
	
EndFunction // GetGeneratedByText()

//// Returns default value of remarks for combination of document and customer/supplier

//Function GetDocumentRemarksStructure(DocumentObject, BusinessPartner = Undefined) Export
//	
//	Query = New Query;
//	Query.Text = "SELECT
//	             |	DocumentRemarks.Remarks AS Remarks,
//	             |	CASE
//	             |		WHEN DocumentRemarks.BusinessPartner = &EmptyBusinessPartner
//	             |			THEN 1
//	             |		ELSE 0
//	             |	END AS BusinessPartnerOrder,
//	             |	DocumentRemarks.AdditionalInformation
//	             |FROM
//	             |	InformationRegister.DocumentRemarks AS DocumentRemarks
//	             |WHERE
//	             |	DocumentRemarks.DocumentType = &DocumentType
//	             |	AND (DocumentRemarks.BusinessPartner = &BusinessPartner
//	             |			OR DocumentRemarks.BusinessPartner = &EmptyBusinessPartner)
//	             |
//	             |ORDER BY
//	             |	BusinessPartnerOrder";
//	
//	Query.SetParameter("DocumentType", New(TypeOf(DocumentObject.Ref)));
//	Query.SetParameter("BusinessPartner", BusinessPartner);
//	Query.SetParameter("EmptyBusinessPartner", Undefined);
//	
//	Selection = Query.Execute().Select();
//	
//	If Selection.Next() Then
//		Return New Structure("Remarks, AdditionalInformation",Selection.Remarks,Selection.AdditionalInformation);
//	Else
//		Return New Structure("Remarks, AdditionalInformation","","");
//	EndIf;
//	
//EndFunction


//Function GetDocumentRemarks(DocumentObject, BusinessPartner = Undefined) Export
//	Return GetDocumentRemarksStructure(DocumentObject, BusinessPartner).Remarks;
//EndFunction	


//Procedure FillRemarks(DocumentObject, BusinessPartner = Undefined,Overwrite = False) Export
//	
//	RemarksStructure = GetDocumentRemarksStructure(DocumentObject, BusinessPartner);
//	
//	If IsBlankString(DocumentObject.Remarks) OR Overwrite Then
//		DocumentObject.Remarks = RemarksStructure.Remarks;
//	EndIf;
//	
//	If IsBlankString(DocumentObject.AdditionalInformation) OR Overwrite Then
//		DocumentObject.AdditionalInformation = RemarksStructure.AdditionalInformation;
//	EndIf;
//	
//EndProcedure	

///////////////////////////////////////////////////////////////////////////////////////////////////
////// Acceptance mechanics

//Function DocumentsAcceptance_GenerateQueryByMetadata(DocumentBase)
//	
//	MetadataObject = DocumentBase.Metadata();
//	
//	SelectedAttributes = "";
//	
//	MetadataAttributesArray = New Array();
//	
//	MetadataAttributes = MetadataObject.Attributes;
//	// Predefined items for document
//	SelectedAttributes = SelectedAttributes +  "DataSource.Ref, DataSource.DeletionMark, DataSource.Date, ";
//	If MetadataObject.Posting = Metadata.ObjectProperties.Posting.Allow Then
//		SelectedAttributes = SelectedAttributes +  "DataSource.Posted, ";
//	EndIf;	
//	If MetadataObject.NumberLength > 0 Then
//		SelectedAttributes = SelectedAttributes +  "DataSource.Number, ";
//	EndIf;	
//	MetadataAttributesArray.Add(MetadataAttributes);
//	TableKindName = "Document";
//	
//	For Each MetadataAttributesSet In MetadataAttributesArray Do
//		
//		For each Attribute In MetadataAttributesSet Do
//			
//			SelectedAttributes = SelectedAttributes + "DataSource." + Attribute.Name + ", ";
//						
//		EndDo;
//		
//	EndDo;
//	
//	SelectedAttributes = Left(SelectedAttributes,StrLen(SelectedAttributes)-2);
//	
//	QueryText = " SELECT ALLOWED " + Chars.LF;
//	
//	QueryText = QueryText + SelectedAttributes + 
//	" FROM "+ TableKindName + "." + MetadataObject.Name;
//	
//	QueryText = QueryText + " AS DataSource";
//	
//	Return QueryText;
//	
//EndFunction	


//Function DocumentsAcceptance_DataCompositionSettingsComposer(DocumentBase) Export
//	
//	MetadataObject = DocumentBase.Metadata();
//	
//	DCS = New DataCompositionSchema;
//	
//	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
//	
//	DataSource = TemplateReports.AddLocalDataSource(DCS);
//	
//	DataSet = TemplateReports.AddDataSetQuery(DCS.DataSets, DataSource);
//	DataSet.Query = DocumentsAcceptance_GenerateQueryByMetadata(DocumentBase);
//	
//	MetadataAttributes = MetadataObject.Attributes;
//	
//	MetadataAttributesArray = New Array();
//	
//	NewField = TemplateReports.AddDataSetField(DCS.DataSets[0], "Ref", Nstr("en='Reference';pl='Odwołanie';ru='Отмена'"));
//	NewField.AttributeUseRestriction.Field = True;
//	TemplateReports.AddDataSetField(DCS.DataSets[0], "DeletionMark", Nstr("en='Deletion mark';pl='Zaznaczenie do usunięcia'"));
//	TemplateReports.AddDataSetField(DCS.DataSets[0], "Date", Nstr("en='Date';pl='Data'"));
//	If MetadataObject.Posting = Metadata.ObjectProperties.Posting.Allow Then
//		TemplateReports.AddDataSetField(DCS.DataSets[0], "Posted", Nstr("en='Posted';pl='Zatwierdzony'"));
//	EndIf;	
//	If MetadataObject.NumberLength > 0 Then
//		TemplateReports.AddDataSetField(DCS.DataSets[0], "Number", Nstr("en='Number';pl='Numer';ru='Номер'"));
//	EndIf;	
//	MetadataAttributesArray.Add(MetadataAttributes);

//	For Each MetadataAttributesSet In MetadataAttributesArray Do
//		For each Attribute In MetadataAttributesSet Do
//			AddedField = TemplateReports.AddDataSetField(DCS.DataSets[0], Attribute.Name, Attribute.Synonym);
//		EndDo;
//	EndDo;
//	
//	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCS));
//	Return DataCompositionSettingsComposer;

//EndFunction	


//Function DocumentsAcceptance_GetSchemaRef(DocumentRef,ErrorText) Export
//	
//	MetadataObject = DocumentRef.Metadata();	
//	DocumentTypeEmptyRef = Documents[MetadataObject.Name].EmptyRef();
//	
//	AcceptWithSchemaOnly = Undefined;
//	
//	Query = New Query;
//	Query.Text = "SELECT
//	             |	DocumentsAcceptanceSettings.UseAcceptance,
//	             |	DocumentsAcceptanceSettings.AcceptWithSchemaOnly
//	             |FROM
//	             |	InformationRegister.DocumentsAcceptanceSettings AS DocumentsAcceptanceSettings
//	             |WHERE
//	             |	DocumentsAcceptanceSettings.DocumentType = &DocumentType";
//	Query.SetParameter("DocumentType",DocumentTypeEmptyRef);
//	QueryResult = Query.Execute();
//	If QueryResult.IsEmpty() Then	
//		Return Catalogs.DocumentsAcceptanceSchemas.EmptyRef();
//	Else
//		Selection = QueryResult.Select();
//		Selection.Next();
//		If NOT Selection.UseAcceptance Then
//			Return Catalogs.DocumentsAcceptanceSchemas.EmptyRef();
//		Else
//			AcceptWithSchemaOnly = Selection.AcceptWithSchemaOnly;
//		EndIf;	
//	EndIf;	
//	
//	ValueList = New ValueList();
//	
//	QueryTextTemplate = " SELECT ALLOWED * " + Chars.LF+ 
//	" FROM Document." + MetadataObject.Name + " AS DataSource";
//	
//	Query = New Query();
//	Query.Text = "SELECT DISTINCT
//	             |	DocumentsAcceptanceSchemasUsersApplied.Ref
//	             |FROM
//	             |	Catalog.DocumentsAcceptanceSchemas.UsersApplied AS DocumentsAcceptanceSchemasUsersApplied
//	             |WHERE
//	             |	DocumentsAcceptanceSchemasUsersApplied.Ref.DocumentType = &DocumentType
//	             |	AND DocumentsAcceptanceSchemasUsersApplied.Ref.Blocked = FALSE
//	             |	AND DocumentsAcceptanceSchemasUsersApplied.User = &Author
//	             |
//	             |UNION
//	             |
//	             |SELECT DISTINCT
//	             |	DocumentsAcceptanceSchemas.Ref
//	             |FROM
//	             |	Catalog.DocumentsAcceptanceSchemas AS DocumentsAcceptanceSchemas
//	             |WHERE
//	             |	DocumentsAcceptanceSchemas.Blocked = FALSE
//	             |	AND DocumentsAcceptanceSchemas.ApplyToAllUsers";
//					 
//	Query.SetParameter("DocumentType",DocumentTypeEmptyRef);
//	Query.SetParameter("Author",DocumentRef.Author);
//	Selection = Query.Execute().Select();
//	
//	DCS = New DataCompositionSchema;
//	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
//	TemplateComposer = New DataCompositionTemplateComposer;	
//	
//	DataSource = TemplateReports.AddLocalDataSource(DCS);
//	DataSet = TemplateReports.AddDataSetQuery(DCS.DataSets, DataSource);
//	DataSet.Query = QueryTextTemplate;
//	
//	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCS));
//	NewGroup = DataCompositionSettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
//	NewGroupField = NewGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
//	NewGroupField.Field = New DataCompositionField("Ref");
//	
//	TempQuery = New Query();
//	TempQuery.Text = "";
//	
//	i = 0;
//	TemplatesToQueryArray = New Array();
//	
//	While Selection.Next() Do	
//	
//		FilterAsXML = Selection.Ref.Filter.Get();
//		
//		If IsBlankString(FilterAsXML) Then
//			
//			ValueList.Add(Selection.Ref);
//			Continue;
//			
//		Else	
//			
//			TemplateReports.CopyItems(DataCompositionSettingsComposer.Settings.Filter,GetObjectFromXML(FilterAsXML,Type("DataCompositionFilter")),True,True);
//			TemplateReports.AddFilter(DataCompositionSettingsComposer,"Ref",DocumentRef);
//			CompositionTemplate = TemplateComposer.Execute(DCS, DataCompositionSettingsComposer.Settings,,,Type("DataCompositionValueCollectionTemplateGenerator"));
//			
//			iQuery = CompositionTemplate.DataSets.DataSet1.Query;
//			For Each Parameter In CompositionTemplate.ParameterValues Do
//				TempQuery.SetParameter("T"+i+Parameter.Name,Parameter.Value);
//				iQuery = StrReplace(iQuery,"&"+Parameter.Name,"&T"+i+Parameter.Name);
//			EndDo;	
//			
//			TempQuery.Text = TempQuery.Text + iQuery + ";";
//			i=i+1;
//			
//			TemplatesToQueryArray.Add(Selection.Ref);
//			
//		EndIf;
//				
//	EndDo;	
//	
//	If NOT IsBlankString(TempQuery.Text) Then
//		
//		TempQueryResultArray = TempQuery.ExecuteBatch();
//		
//		i=0;
//		For Each TempQueryResultArrayItem In TempQueryResultArray Do
//			
//			If Not TempQueryResultArrayItem.IsEmpty() Then
//				
//				ValueList.Add(TemplatesToQueryArray[i]);
//				
//			EndIf;	
//			
//			i=i+1;
//			
//		EndDo;	
//		
//	EndIf;	
//	
//	ValueListCount = ValueList.Count();
//	If ValueListCount= 0 Then
//		If AcceptWithSchemaOnly Then
//			ErrorText = Nstr("en = 'There is no schemas for document was found!'; pl = 'Nie znaleziono żadnego schemat akceptacji dla dokumentu!'");
//			Return Undefined;
//		Else
//			Return Catalogs.DocumentsAcceptanceSchemas.EmptyRef();
//		EndIf;	
//	ElsIf ValueListCount>1 Then
//		ErrorText = Nstr("en = 'Too many schemas for document were found!'; pl = 'Znaleziono ponad jeden schemat akceptacji dla dokumentu!'");
//		Return Undefined;
//	Else	
//		Return ValueList[0].Value;
//	EndIf;	
//	
//EndFunction	

//////////////////////////////////////////////////////////////////////////////////
//// Data fast filter

//Function SuppliersFastFilter(FastFilter, PortionSize = 100,GetDescription = False,AskAboutCountOfGettingPortions = False, GetAllPortions = True) Export
//		
//	SearchAreaTable = New ValueTable;
//	SearchAreaTable.Columns.Add("Metadata");
//	SearchAreaTable.Columns.Add("Field",GetStringTypeDescription(0));
//	SearchAreaTable.Columns.Add("NeedFieldTypeCheck",GetBooleanTypeDescription());
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.Catalogs.Suppliers;
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.Catalogs.ContactPersons;
//	NewRow.Field = "Owner";
//	NewRow.NeedFieldTypeCheck = True;
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.Catalogs.BankAccounts;
//	NewRow.Field = "Owner";
//	NewRow.NeedFieldTypeCheck = True;
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.InformationRegisters.ContactInformation;
//	NewRow.Field = "Object";
//	NewRow.NeedFieldTypeCheck = True;

//	Return PerformFullTextSearch(FastFilter,Type("CatalogRef.Suppliers"),SearchAreaTable,PortionSize,GetDescription,AskAboutCountOfGettingPortions,GetAllPortions);
//		
//EndFunction	


//Function CustomersFastFilter(FastFilter, PortionSize = 100,GetDescription = False,AskAboutCountOfGettingPortions = False, GetAllPortions = True) Export
//	
//	SearchAreaTable = New ValueTable;
//	SearchAreaTable.Columns.Add("Metadata");
//	SearchAreaTable.Columns.Add("Field",GetStringTypeDescription(0));
//	SearchAreaTable.Columns.Add("NeedFieldTypeCheck",GetBooleanTypeDescription());
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.Catalogs.Customers;
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.Catalogs.ContactPersons;
//	NewRow.Field = "Owner";
//	NewRow.NeedFieldTypeCheck = True;
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.Catalogs.BankAccounts;
//	NewRow.Field = "Owner";
//	NewRow.NeedFieldTypeCheck = True;
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.InformationRegisters.CustomersCompaniesCodes;
//	NewRow.Field = "Customer";
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.InformationRegisters.ContactInformation;
//	NewRow.Field = "Object";
//	NewRow.NeedFieldTypeCheck = True;

//	Return PerformFullTextSearch(FastFilter,Type("CatalogRef.Customers"),SearchAreaTable,PortionSize,GetDescription,AskAboutCountOfGettingPortions,GetAllPortions);
//		
//EndFunction	


//Function ItemsFastFilter(FastFilter,PortionSize = 100,GetDescription = False,AskAboutCountOfGettingPortions = False, GetAllPortions = True) Export
//	
//	SearchAreaTable = New ValueTable;
//	SearchAreaTable.Columns.Add("Metadata");
//	SearchAreaTable.Columns.Add("Field",GetStringTypeDescription(0));
//	SearchAreaTable.Columns.Add("NeedFieldTypeCheck",GetBooleanTypeDescription());
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.Catalogs.Items;
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.InformationRegisters.BarCodes;
//	NewRow.Field = "Object";
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.InformationRegisters.SuppliersItems;
//	NewRow.Field = "Item";
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.InformationRegisters.CustomersItems;
//	NewRow.Field = "Item";

//	Return PerformFullTextSearch(FastFilter,Type("CatalogRef.Items"),SearchAreaTable,PortionSize,GetDescription,AskAboutCountOfGettingPortions,GetAllPortions);
//		
//EndFunction	


//Function SalesOrdersFastFilter(FastFilter,PortionSize = 100,GetDescription = False,AskAboutCountOfGettingPortions = False, GetAllPortions = True) Export
//	
//	SearchAreaTable = New ValueTable;
//	SearchAreaTable.Columns.Add("Metadata");
//	SearchAreaTable.Columns.Add("Field",GetStringTypeDescription(0));
//	SearchAreaTable.Columns.Add("NeedFieldTypeCheck",GetBooleanTypeDescription());
//	NewRow = SearchAreaTable.Add();
//	NewRow.Metadata = Metadata.Documents.SalesOrder;

//	Return PerformFullTextSearch(FastFilter,Type("DocumentRef.SalesOrder"),SearchAreaTable,PortionSize,GetDescription,AskAboutCountOfGettingPortions,GetAllPortions);
//		
//EndFunction	


//Function PerformFullTextSearch(FastFilter,OutputType,SearchAreaTable,PortionSize = 100,GetDescription = False, AskAboutCountOfGettingPortions = False, GetAllPortions = True) Export
//	
//	ReturnStructure = New Structure("SearchStringIsEmpty, FoundMoreItemsThanShowed, FoundCount, PreciseSearchString, RefsArray, FullTextSearchList",False,False,0,False,Undefined,Undefined);
//	
//	If IsBlankString(FastFilter) Then
//		ReturnStructure.SearchStringIsEmpty = True;
//	ElsIf StrLen(TrimAll(FastFilter)) <=2 Then
//		ReturnStructure.PreciseSearchString = True;
//	Else
//		
//		SearchStringsArray = GetSearchSubStringsArray(FastFilter);
//		
//		FullTextSearchString = "";
//		For Each SearchString In SearchStringsArray Do
//			FullTextSearchString = FullTextSearchString + SearchString + ?(StrLen(SearchString)>2 AND NOT IsFullTextSearchSpecialSymbolInWord(SearchString),"* "," ");
//		EndDo;	
//		
//		SearchList = FullTextSearch.CreateList(FullTextSearchString, PortionSize);
//		SearchList.SearchArea = SearchAreaTable.UnloadColumn("Metadata");
//		SearchList.GetDescription = GetDescription;
//		Try
//			SearchList.FirstPart();
//		Except
//			ReturnStructure.PreciseSearchString = True;
//		EndTry;	
//		
//		If NOT ReturnStructure.PreciseSearchString AND (SearchList.TooManyResults() OR SearchList.TotalCount()>1000) Then
//			#If Client Then
//				ShowMessageBox(, Nstr("en='Too many results, please precise query';pl='Za dużo wyników - uściślij zapytanie'")+".");
//			#EndIf	
//			ReturnStructure.PreciseSearchString = True;
//		EndIf;
//		
//		If NOT ReturnStructure.PreciseSearchString Then
//			TmpTable = New ValueTable();
//			TmpTable.Columns.Add("Ref");
//			
//			NeedLoop = ?(SearchList.TotalCount()>PortionSize,True,False);
//			
//			If NeedLoop Then
//				If AskAboutCountOfGettingPortions Then
//					#If Client Then
//						DialogReturn = DoQueryBox(Alerts.ParametrizeString(Nstr("en = 'There are more than %P1 objects found! Do you want to show all %P2 objects?
//						|Choose ''Yes'' to show %P2 objects, choose ''No'' to show %P1 objects.'; pl = 'Znaleziono ponad %P1 pozycji! Czy chcesz wyświetlić wszystkie %P2 obiektów?
//						|Wybierz ''Tak'' aby wyświetlić %P2 obiektów, wybierz ''Nie'' aby wyświetlić %P1 obiektów.'"),New Structure("P1, P2",PortionSize,SearchList.TotalCount())),QuestionDialogMode.YesNo,,DialogReturnCode.No);
//						If DialogReturn = DialogReturnCode.No Then
//							NeedLoop = False;
//						EndIf;	
//					#ElsIf Server Then
//						NeedLoop = False;
//					#EndIf	
//				Else
//					If NOT GetAllPortions Then
//						NeedLoop = False;
//					EndIf;	
//				EndIf;	
//			EndIf;
//			
//			While (SearchList.TotalCount() - SearchList.StartPosition()) >= SearchList.Count() Do
//				
//				For Each SearchListItem In SearchList Do
//					
//					FoundRow = FindTabularPartRow(SearchAreaTable, New Structure("Metadata",SearchListItem.Metadata));
//					If FoundRow = Undefined Then
//						Continue;
//					EndIf;
//					
//					If FoundRow.NeedFieldTypeCheck AND TypeOf(SearchListItem.Value[FoundRow.Field])<>OutputType Then
//						
//						Continue;
//						
//					EndIf;	
//					
//					NewRow = TmpTable.Add();
//					If IsBlankString(FoundRow.Field) Then
//						NewRow.Ref = SearchListItem.Value;
//					Else
//						NewRow.Ref = SearchListItem.Value[FoundRow.Field];
//					EndIf;	
//					
//				EndDo;	
//				
//				If NOT NeedLoop Then
//					Break;
//				Else
//					If (SearchList.TotalCount() - SearchList.StartPosition()) > SearchList.Count() Then
//						SearchList.NextPart();
//					Else
//						Break;
//					EndIf;	
//				EndIf;	
//				
//			EndDo;
//			
//			TmpTable.GroupBy("Ref");
//			ReturnStructure.FoundMoreItemsThanShowed = ?(SearchList.TotalCount()>PortionSize,True,False);
//			ReturnStructure.FoundCount = SearchList.TotalCount();
//			ReturnStructure.RefsArray = TmpTable.UnloadColumn("Ref");
//			ReturnStructure.FullTextSearchList = SearchList;
//		EndIf;

//	EndIf;	

//		
//	#If Client Then	
//		If ReturnStructure.PreciseSearchString Then
//			ShowMessageBox(, Nstr("en='Please, precise search condition!';pl='Sprecyzuj warunek wyszukiwania!';ru='Укажите условие поиска!'"));
//		EndIf;
//	#EndIf	
//	
//	Return ReturnStructure;
//	
//EndFunction	


//Function GetCompanyLogo(Company) Export
//	
//	RecordSet = InformationRegisters.CompanyLogo.CreateRecordSet();
//	RecordSet.Filter.Company.Set(Company);
//	RecordSet.Read();
//	
//	If RecordSet.Count()>0 Then
//		
//		Record = RecordSet[0];
//		CompanyLogo = Record.Logo.Get();
//		
//		If TypeOf(CompanyLogo) = Type("BinaryData") Then
//			Return New Picture(CompanyLogo);
//		Else
//			Return New Picture;
//		EndIf;
//	Else	
//		Return New Picture;
//	EndIf;
//		
//EndFunction // GetCompanyLogo()


Function GetAttribute(ObjectRef,AttributeName,Cancel = False) Export
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	             |	ObjectTable."+AttributeName+" AS " + AttributeName + "
	             |FROM
	             |	"+GetMetadataClassName(TypeOf(ObjectRef))+"."+ObjectRef.Metadata().Name+" AS ObjectTable
	             |WHERE
	             |	ObjectTable.Ref = &Ref";
	Query.SetParameter("Ref",ObjectRef);
	QueryResult = Query.Execute();
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection[AttributeName];
		
	EndIf;	
	
	Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Error reading object''s %P1 attribute %P2!'; pl = 'Błąd odczytu atrybutu %P2 dla %P1!'"),New Structure("P1, P2",ObjectRef,AttributeName)),Enums.AlertType.Error,Cancel,ObjectRef);
	Return Undefined;
	
EndFunction	


Function GetMetadataClassName(ObjectRefType) Export
	
	If Catalogs.AllRefsType().ContainsType(ObjectRefType) Then
		Return "Catalog";
	ElsIf Documents.AllRefsType().ContainsType(ObjectRefType) Then	
		Return "Document";
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(ObjectRefType) Then
		Return "ChartOfAccounts";
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(ObjectRefType) Then
		Return "ChartOfCalculationTypes";
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(ObjectRefType) Then
		Return "ChartOfCharacteristicTypes";
	ElsIf ExchangePlans.AllRefsType().ContainsType(ObjectRefType) Then
		Return "ExchangePlan";
	ElsIf Enums.AllRefsType().ContainsType(ObjectRefType) Then
		Return "Enum";
	EndIf;		
	
EndFunction	


Function GetLastFinancialYear() Export
	
	Query = New Query;
	
	Query.Text = "SELECT
	|	FinancialYears.DateFrom AS DateFrom,
	|	FinancialYears.Ref,
	|	CASE
	|		WHEN FinancialYears.DateFrom > &CurrentYear
	|			THEN 0
	|		ELSE 1
	|	END AS Field1
	|FROM
	|	Catalog.FinancialYears AS FinancialYears
	|
	|ORDER BY
	|	Field1 DESC,
	|	DateFrom DESC";
	
	Query.SetParameter("CurrentYear", BegOfYear(CurrentDate()));
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		Return '00010101';
	EndIf;
	
EndFunction

//Function CommonSettingsStorageLoad() Export
//	
//	DontShowUserSettingsWizardOnStart = (CommonSettingsStorage.Load("InfobaseUsers","DontShowUserSettingsWizardOnStart") <> False);
//		
//	Right_Administration_ConfigurationAdministration = IsInRole("Right_Administration_ConfigurationAdministration");
//	
//	Settings = New Structure("DontShowUserSettingsWizardOnStart,Right_Administration_ConfigurationAdministration",
//								DontShowUserSettingsWizardOnStart,
//								Right_Administration_ConfigurationAdministration);
//	Return Settings;
//	
//EndFunction

////Load current policy
////Check password  on compliance current security policies
////Parameters:
////NewPassword - string - new password
//Function CheckPassword(NewPassword) Export
//	
//	CurrentSettingsPassword = Constants.PasswordComplexitySettings.Get().Get();
//	
//	If TypeOf(CurrentSettingsPassword) = Type("Structure") Then
//		
//		//Parameters complexity password
//		CheckingPasswordComplexity = CurrentSettingsPassword.CheckingPasswordComplexity;
//		MinimumPasswordLength = CurrentSettingsPassword.MinimumPasswordLength;
//		UseNumber = CurrentSettingsPassword.UseNumber;
//		UseLowerCase = CurrentSettingsPassword.UseLowerCase;
//		UseUpperCase = CurrentSettingsPassword.UseUpperCase;
//		UseSpecialCharacters = CurrentSettingsPassword.UseSpecialCharacters;
//				
//		//Password is difficult 
//		ErrorPasswordLength = False;
//		Number = False;
//		LowerCase = False;
//		UpperCase = False; 
//		SpecialCharacters = False;
//		ErrorCheck = False;
//		
//		//Structure error for users
//		ErrorUseNumber = False;
//		ErrorUseLowerCase = False;
//		ErrorUseUpperCase = False;
//		ErrorUseSpecialCharacters = False;
//		
//		If CheckingPasswordComplexity Then //need check password complexity new password
//			LenNewPassword = StrLen(NewPassword);
//			If LenNewPassword >= MinimumPasswordLength Then
//				ErrorPasswordLength = True;
//			EndIf;
//				
//			For n=1 To StrLen(NewPassword) Do
//				Code=CharCode(NewPassword, n);
//				If (Code>=CharCode("0")) And (Code<=CharCode("9")) Then 
//					Number=True; 
//				ElsIf ((Code>=CharCode("a")) And (Code<=CharCode("z"))) Then 
//					LowerCase=True;				  
//				ElsIf ((Code>=CharCode("A")) And (Code<=CharCode("Z"))) Then 
//					UpperCase=True;
//				Else 
//					SpecialCharacters=True;	
//				EndIf;
//			EndDo;           
//			
//			If (UseNumber AND Not Number) Then
//				ErrorCheck = True;
//				ErrorUseNumber = True;
//			EndIf;
//			If (UseLowerCase AND Not LowerCase) Then 
//				ErrorCheck = True;
//				ErrorUseLowerCase = True;
//			EndIf;
//			If (UseUpperCase AND Not UpperCase) Then
//				ErrorCheck = True;
//				ErrorUseUpperCase = True;
//			EndIf;
//			If (UseSpecialCharacters AND Not SpecialCharacters) Then
//				ErrorCheck = True;
//				ErrorUseSpecialCharacters = True;
//			EndIf;

//			Return New Structure("MinimumPasswordLength,ErrorPasswordLength,ErrorCheck,ErrorUseNumber,ErrorUseLowerCase,ErrorUseUpperCase,ErrorUseSpecialCharacters",
//			MinimumPasswordLength,ErrorPasswordLength,ErrorCheck,ErrorUseNumber,ErrorUseLowerCase,ErrorUseUpperCase,UseSpecialCharacters);  
//						
//		Else
//			Return New Structure("ErrorCheck",False);  
//			
//		EndIf;
//		
//	Else
//		Return New Structure("ErrorCheck",False);
//	EndIf;

//EndFunction

//Function NeedSetSalesPrice(ObjectMetadataName) Export 
//	Return IsDocumentAttribute("PriceType",Metadata.Documents[ObjectMetadataName])
//		And IsDocumentAttribute("Currency",Metadata.Documents[ObjectMetadataName])
//		And IsDocumentAttribute("AmountType",Metadata.Documents[ObjectMetadataName])
//		And IsDocumentAttribute("Customer",Metadata.Documents[ObjectMetadataName])
//		And IsDocumentAttribute("DiscountGroup",Metadata.Documents[ObjectMetadataName]);
//EndFunction
////	
////Procedure AdjustFormGroupsToOrdinaryApplication(Form) Export
////	
////	For Each FormItem In Form.Items Do
////		If TypeOf(FormItem) = Type("FormGroup")
////			AND  FormItem.Type = FormGroupType.UsualGroup 
////			AND  NOT FormItem.ShowTitle Then
////			FormItem.Representation = UsualGroupRepresentation.None;
////		EndIf;	
////	EndDo;	
////	
////EndProcedure	

Function GetNationalCurrency() Export
	Return DefaultValuesAtServer.GetNationalCurrency();
EndFunction

Function GetAccountMandatory(Account,Counter) Export
	Return Account.ExtDimensionTypes[Counter-1].Mandatory;
EndFunction

Function GetVisibilityBookkeepingOperationCommand(FormName) Export
	ShowBookkeepingOperationCommand = True;
	TmpFormName = FormName;
	IndexOfDot = StrFind(TmpFormName,".");
	If IndexOfDot>0 AND Left(TmpFormName,IndexOfDot-1) = "Document" AND IndexOfDot<StrLen(TmpFormName) Then
		TmpFormName = Right(TmpFormName,StrLen(TmpFormName)-IndexOfDot);
		IndexOfDot = StrFind(TmpFormName,".");
		If IndexOfDot>0 Then
			MetadataName = Left(TmpFormName,IndexOfDot-1);		
			If MetadataName = "BookkeepingOperation" Then
				ShowBookkeepingOperationCommand = False;					
			Else	
				RecordKey = InformationRegisters.BookkeepingPostingSettings.Get(New Structure("Object",New (Type("DocumentRef."+MetadataName))));
				If RecordKey.BookkeepingPostingType = Enums.BookkeepingPostingTypes.DontPost Then	
					ShowBookkeepingOperationCommand = False;					
				EndIf;
			EndIf;			
		EndIf;
	EndIf;
	
	Return ShowBookkeepingOperationCommand;
EndFunction

Function IsAccessRight(Access, FullNameObject) Export
	Return AccessRight(Access, Eval(FullNameObject));
EndFunction

//Function NeedUpdateInfoBase() Export
//	Return Not Metadata.Version = Constants.DatabaseVersion.Get();
//EndFunction

Function IsDocumentTabularPartAttribute(AttributeName, DocumentRef, TabularPartName) Export 
	
	TabularPart = DocumentRef.Metadata().TabularSections.Find(TabularPartName);
	
	If TabularPart = Undefined Then
		Return False;
	Else
		Return Not (TabularPart.Attributes.Find(AttributeName) = Undefined);
	EndIf;

EndFunction

//Function InitializeArraysCharacter()
//	
//	mNumber = New Array();	
//	mNumber.Add("0");mNumber.Add("1");mNumber.Add("2");mNumber.Add("3");mNumber.Add("4");
//	mNumber.Add("5");mNumber.Add("6");mNumber.Add("7");mNumber.Add("8");mNumber.Add("9");	
//		
//	mLatinLowerCase = New Array();
//	mLatinLowerCase.Add("a");mLatinLowerCase.Add("b");mLatinLowerCase.Add("c");mLatinLowerCase.Add("d");mLatinLowerCase.Add("e");
//	mLatinLowerCase.Add("f");mLatinLowerCase.Add("g");mLatinLowerCase.Add("h");mLatinLowerCase.Add("i");mLatinLowerCase.Add("j");
//	mLatinLowerCase.Add("k");mLatinLowerCase.Add("l");mLatinLowerCase.Add("m");mLatinLowerCase.Add("n");mLatinLowerCase.Add("o");
//	mLatinLowerCase.Add("p");mLatinLowerCase.Add("q");mLatinLowerCase.Add("r");mLatinLowerCase.Add("s");mLatinLowerCase.Add("t");
//	mLatinLowerCase.Add("u");mLatinLowerCase.Add("v");mLatinLowerCase.Add("w");mLatinLowerCase.Add("x");mLatinLowerCase.Add("y");
//	mLatinLowerCase.Add("z");
//	
//	mLatinUpperCase = New Array();	
//	For n = 0 to mLatinLowerCase.Count()-1 Do
//		mLatinUpperCase.Add(Upper(mLatinLowerCase[n]));	
//	EndDo; 
//	
//	mSymbols = New Array();
//	mSymbols.Add("!");mSymbols.Add("""");mSymbols.Add("#");mSymbols.Add("$");
//	mSymbols.Add("%");mSymbols.Add("&");mSymbols.Add("'");mSymbols.Add("(");mSymbols.Add(")");
//	mSymbols.Add("*");mSymbols.Add("+");mSymbols.Add(",");mSymbols.Add("-");mSymbols.Add(".");
//	mSymbols.Add("/");mSymbols.Add(":");mSymbols.Add(";");mSymbols.Add("<");mSymbols.Add("=");
//	mSymbols.Add(">");mSymbols.Add("?");mSymbols.Add("@");mSymbols.Add("[");mSymbols.Add("\");
//	mSymbols.Add("]");mSymbols.Add("^");mSymbols.Add("_");mSymbols.Add("`");mSymbols.Add("{");
//	mSymbols.Add("|");mSymbols.Add("}");mSymbols.Add("~");
//	
//	Return New Structure("mNumber,mLatinLowerCase,mLatinUpperCase,mSymbols",mNumber,mLatinLowerCase,mLatinUpperCase,mSymbols);
//	
//EndFunction	

//Function GeneratePassword() Export
//	
//	Password = "";
//	
//	StructureCharacter = InitializeArraysCharacter();
//	mNumber = StructureCharacter.mNumber;
//	mLatinLowerCase = StructureCharacter.mLatinLowerCase;
//	mLatinUpperCase = StructureCharacter.mLatinUpperCase;
//	mSymbols = StructureCharacter.mSymbols;
//	
//	CurrentSymbol = -1;
//	AlreadyHadUpperCase = False;
//	AlreadyHadLowerCase = False;

//	CurrentSettingsPassword = Constants.PasswordComplexitySettings.Get().Get();
//	
//	If TypeOf(CurrentSettingsPassword) = Type("Structure") Then
//		CheckingPasswordComplexity = CurrentSettingsPassword.CheckingPasswordComplexity;
//		MinimumPasswordLength = CurrentSettingsPassword.MinimumPasswordLength;
//		UseNumber = CurrentSettingsPassword.UseNumber;
//		UseLowerCase = CurrentSettingsPassword.UseLowerCase;
//		UseUpperCase = CurrentSettingsPassword.UseUpperCase;
//		UseSpecialCharacters = CurrentSettingsPassword.UseSpecialCharacters;
//	Else
//		CheckingPasswordComplexity = False;
//	EndIf;
//			
//	If Not CheckingPasswordComplexity Then
//		//parameters for generate default password
//		UseNumber = True;
//		UseLowerCase = True;
//		UseUpperCase = True;
//		UseSpecialCharacters = True;
//		MinimumPasswordLength = 8;
//	Else 
//		If UseNumber = False And UseLowerCase = False And UseUpperCase = False And UseSpecialCharacters = False Then
//			UseNumber = True;
//			UseLowerCase = True;
//			UseUpperCase = True;
//			UseSpecialCharacters = True;
//			If MinimumPasswordLength = Undefined Then
//				MinimumPasswordLength = 8;
//			EndIf;
//		EndIf;
//	EndIf;
//	
//	RNG = New RandomNumberGenerator;
//	LenPassword = RNG.RandomNumber(MinimumPasswordLength, MinimumPasswordLength);
//	ArrayPassword = New Array(MinimumPasswordLength);

//	MaxRandomValue = 0;
//	MaxRandomValue = MaxRandomValue + ?(UseNumber, mNumber.Count(), 0);
//	MaxRandomValue = MaxRandomValue + ?(UseLowerCase, mLatinLowerCase.Count(), 0);
//	MaxRandomValue = MaxRandomValue + ?(UseUpperCase, mLatinUpperCase.Count(), 0);
//	MaxRandomValue = MaxRandomValue + ?(UseSpecialCharacters, mSymbols.Count(), 0);
//	
//	If UseNumber Then
//		RandomNumber = RNG.RandomNumber(1,mNumber.Count());
//		CurrentSymbol = CurrentSymbol + 1;
//		ArrayPassword[CurrentSymbol] = mNumber[RandomNumber-1];
//	EndIf;	
//	
//	If UseLowerCase Then
//		RandomNumber=RNG.RandomNumber(1,mLatinLowerCase.Count());
//		CurrentSymbol = CurrentSymbol + 1;
//		ArrayPassword[CurrentSymbol] = mLatinLowerCase[RandomNumber-1];
//		If (UseUpperCase) And (Not AlreadyHadUpperCase) Then 
//			ArrayPassword[CurrentSymbol] = Upper(ArrayPassword[CurrentSymbol]); 
//			AlreadyHadUpperCase = True;
//		EndIf;
//	EndIf;	
//	
//	If UseUpperCase Then
//		RandomNumber=RNG.RandomNumber(1,mLatinUpperCase.Count());
//		CurrentSymbol = CurrentSymbol + 1;
//		ArrayPassword[CurrentSymbol] = mLatinUpperCase[RandomNumber-1];
//		If (UseLowerCase) And (Not AlreadyHadLowerCase) Then 
//			ArrayPassword[CurrentSymbol] = Lower(ArrayPassword[CurrentSymbol]); 
//			AlreadyHadLowerCase = True;
//		EndIf;
//	EndIf;	
//	
//	If (UseLowerCase) And (Not AlreadyHadLowerCase) Then
//		RandomNumber = RNG.RandomNumber(1,mLatinUpperCase.Count());
//		CurrentSymbol = CurrentSymbol + 1;
//		ArrayPassword[CurrentSymbol] = Lower(mLatinUpperCase[RandomNumber-1]);			
//	EndIf;	
//	
//	If UseUpperCase Then
//		RandomNumber = RNG.RandomNumber(1,mLatinUpperCase.Count());
//		CurrentSymbol = CurrentSymbol + 1;
//		ArrayPassword[CurrentSymbol] = mLatinUpperCase[RandomNumber-1];			
//	EndIf;	
//		
//	If UseSpecialCharacters Then
//		RandomNumber = RNG.RandomNumber(1, mSymbols.Count());
//		CurrentSymbol = CurrentSymbol + 1;
//		ArrayPassword[CurrentSymbol] = mSymbols[RandomNumber-1];
//	EndIf;	
//	
//	//Other symbols
//	While CurrentSymbol < (ArrayPassword.Count()-1) Do
//		
//		RandomNumber = RNG.RandomNumber(1, MaxRandomValue);
//		CurrentSymbol = CurrentSymbol + 1;
//		
//		If UseNumber Then
//			If RandomNumber <= mNumber.Count() Then
//				ArrayPassword[CurrentSymbol] = mNumber[RandomNumber-1];
//				Continue;
//			Else
//				RandomNumber = RandomNumber - mNumber.Count();	
//			EndIf;	
//		EndIf;	
//			
//		If UseLowerCase Then
//			If RandomNumber <= mLatinLowerCase.Count() Then
//				ArrayPassword[CurrentSymbol] = mLatinLowerCase[RandomNumber-1];
//				Continue;
//			Else
//				RandomNumber = RandomNumber - mLatinLowerCase.Count();	
//			EndIf;	
//		EndIf;	
//		
//		If UseUpperCase Then
//			If RandomNumber <= mLatinUpperCase.Count() Then
//				ArrayPassword[CurrentSymbol] = mLatinUpperCase[RandomNumber-1];
//				Continue;
//			Else
//				RandomNumber = RandomNumber - mLatinUpperCase.Count();	
//			EndIf;	
//		EndIf;	
//		
//		If (UseLowerCase) And (UseUpperCase) Then
//			If RandomNumber <= mLatinUpperCase.Count() Then
//				ArrayPassword[CurrentSymbol]=mLatinUpperCase[RandomNumber-1];
//				Continue;
//			Else
//				RandomNumber = RandomNumber-mLatinUpperCase.Count();	
//			EndIf;	
//		EndIf;	
//		
//		If UseSpecialCharacters Then
//			If RandomNumber <= mSymbols.Count() Then
//				ArrayPassword[CurrentSymbol] = mSymbols[RandomNumber-1];
//				Continue;
//			Else
//				RandomNumber = RandomNumber - mSymbols.Count();	
//			EndIf;	
//		EndIf;	
//	EndDo; 
//	
//	//mix	
//	For н=0 По LenPassword-1 Do
//		RandomNumber = RNG.RandomNumber(0, ArrayPassword.Count()-1); 
//		Password = Password + ArrayPassword[RandomNumber];
//		ArrayPassword.Delete(RandomNumber);
//	EndDo;
//	
//	Return Password;
//	
//EndFunction

//#Region SaaSLicenses

//Function GetConstValue(ConstName) Export
//	SetPrivilegedMode(True);
//	
//	Return Constants[ConstName].Get();
//EndFunction

//Procedure SetConstValue(ConstName,Val Value) Export
//	SetPrivilegedMode(True);
//	Constants[ConstName].Set(Value);
//EndProcedure

//Function GetInfoBaseSessionsStructureArray() Export
//	SetPrivilegedMode(True);
//	
//	SessionArray = GetInfoBaseSessions();
//	
//	Result = New Array;
//	For Each Session In SessionArray Do
//		SessionStructure = New Structure;
//		SessionStructure.Insert("ComputerName", Session.ComputerName);
//		SessionStructure.Insert("ApplicationName", Session.ApplicationName);
//		SessionStructure.Insert("SessionStarted", Session.SessionStarted);
//		SessionStructure.Insert("SessionNumber", Session.SessionNumber);
//		SessionStructure.Insert("ConnectionNumber", Session.ConnectionNumber);
//		SessionStructure.Insert("UserID", Session.User.UUID);
//		
//		Result.Add(SessionStructure);
//	EndDo;                                                              	
//	Return Result;
//	
//EndFunction

//Function GetSaaSCheckStructure() Export
//		
//	ReturnStructure = New Structure();
//	ReturnStructure.Insert("SaaSLicensesCount",CommonAtServer.GetConstValue("SaaSLicensesCount"));
//	ReturnStructure.Insert("CurrentSessions",CommonAtServer.GetInfoBaseSessionsStructureArray());
//	ReturnStructure.Insert("IsAdministrator",AccessRight("UpdateDataBaseConfiguration",Metadata));
//	
//	Return ReturnStructure;
//	
//EndFunction	

//#EndRegion