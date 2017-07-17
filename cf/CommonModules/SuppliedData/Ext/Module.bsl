///////////////////////////////////////////////////////////////////////////////////
// SuppliedData: Mechanism of the supplied data service.
//
///////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Initiate notification on all supplied data available in MS
// (excluding one that is marked with "Notification prohibition".
//
Procedure RequestAllData() Export
	
	MessageExchange.SendMessage("SuppliedData\AllDataQuery", Undefined, 
		SaaSReUse.ServiceManagerEndPoint());
		
EndProcedure

// Receive data descriptors by the specified conditions.
//
// Parameters:
//  DataKind - String. 
//  Filter - Collection. Items should contain fields Code (string) and Value (string).
//
// Return
//    value ObjectXDTO of the ArrayOfDescriptor type.
//
Function ProvidedDataFromManagerDescriptors(Val DataKind, Val Filter = Undefined) Export  
	Var Proxy, Conditions, FilterType;
	Proxy = NewProxyOnServiceManager();
	
	If Filter <> Undefined Then
			
		FilterType = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"ArrayOfProperty");
		ConditionType = Proxy.XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"Property");
		Conditions = Proxy.XDTOFactory.Create(FilterType);
		For Each FilterString IN Filter Do
			Condition = Conditions.Property.Add(Proxy.XDTOFactory.Create(ConditionType));
			Condition.Code = FilterString.Code;
			Condition.Value = FilterString.Value;
		EndDo;
	EndIf;
	
	// Convert to the standard type.
	Result = Proxy.GetData(DataKind, Conditions);
	Record = New XMLWriter;
	Record.SetString();
	Proxy.XDTOFactory.WriteXML(Record, Result, , , , XMLTypeAssignment.Explicit);
	SerializedResult = Record.Close();
	
	Read = New XMLReader;
	Read.SetString(SerializedResult);
	Result = XDTOFactory.ReadXML(Read);
	Read.Close();
	Return Result;

EndFunction

// Initializes data processing.
//
// Can be used together with DataSuppliedFromManagerDescriptors for a manual data processor initialization. After the call, the system will behave as if it has just received a notification of the availability of new data with the specified handle - AvailableNewData will be called and later if needed, ProcessNewData for the corresponding handlers.
//
// Parameters:
//   Handle   - XDTOObject Descriptor.
//
Procedure ImportAndProcessData(Val Handle) Export
	
	MessagesSuppliedDataMessageHandler.ProcessNewDescriptor(Handle);
	
EndProcedure
	
// Puts data to the SuppliedData catalog.
//
// Data is saved either to the volume on disc, or to the SuppliedData table field depending on the StoreFilesInVolumesOnDisc constant and presence of the vacant volumes. Data 
// can be extracted later using search by attributes or by 
// specifying a unique identifier that is passed to the Descriptor.FileGUID field. If the base already contains data with the same data kind and key characteristics set - new data replaces the old one. Existing catalog item update is used not removal or creation of a new one.
//
// Parameters:
//   Handle   - ObjectXDTO Descriptor or structure with fields.
//  	"DataKind, AddingDate, FileIdentifier,
//    	Characteristics" where Characteristics - array of structures with fields "Code, Value, Key".
//   PathToFile   - String. The full name of the extracted file.
//
Procedure SaveProvidedDataToCache(Val Handle, Val PathToFile) Export
	
	// Bring the descriptor to the canonical form.
	If TypeOf(Handle) = Type("Structure") Then
		InEnglish = New Structure("DataType, CreationDate, FileGUID, Properties", 
			Handle.DataKind, Handle.AddingDate, Handle.FileID,
			New Structure("Property", New Array));
		If TypeOf(Handle.Characteristics) = Type("Array") Then
			For Each Characteristic IN Handle.Characteristics Do
				InEnglish.Properties.Property.Add(New Structure("Code, Value, IsKey",
				Characteristic.Code, Characteristic.Value, Characteristic.Key));
			EndDo; 
		EndIf;
		Handle = InEnglish;			
	EndIf;
	
	Filter = New Array;
	For Each Characteristic IN Handle.Properties.Property Do
		If Characteristic.IsKey Then
			Filter.Add(New Structure("Code, Value", Characteristic.Code, Characteristic.Value));
		EndIf;
	EndDo;
	
	OriginalDataArea = Undefined;
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		OriginalDataArea = CommonUse.SessionSeparatorValue();
		CommonUse.SetSessionSeparation(False);
	EndIf;
	
	BeginTransaction();
	Try
	
		Query = DataQueryByNames(Handle.DataType, Filter);
		Result = Query.Execute();
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.SuppliedData");
		LockItem.DataSource = Result;
		LockItem.UseFromDataSource("Ref", "SuppliedData");
		Block.Lock();
		
		Selection = Result.Select();
		
		Data = Undefined;
		PathToOldFile = Undefined;
		
		While Selection.Next() Do
			If Data = Undefined Then
				Data = Selection.SuppliedData.GetObject();
				If Data.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
					PathToOldFile = FileFunctionsService.FullPathOfVolume(Data.Volume) + Data.PathToFile;
				EndIf;
			Else
				DeleteProvidedDataFromCache(Selection.SuppliedData);
			EndIf;
		EndDo;		
		
		If Data = Undefined Then
			Data = Catalogs.SuppliedData.CreateItem();
		EndIf;
			
		Data.DataKind =  Handle.DataType;
		Data.AddingDate = Handle.CreationDate;
		Data.FileID = Handle.FileGUID;
		Data.DataCharacteristics.Clear();
		For Each Property IN Handle.Properties.Property Do
			Characteristic = Data.DataCharacteristics.Add();
			Characteristic.Characteristic = Property.Code;
			Characteristic.Value = Property.Value;
		EndDo; 
		Data.FileStorageType = FileFunctionsService.TypeOfFileStorage();

		If Data.FileStorageType = Enums.FileStorageTypes.InInfobase Then
			Data.StoredFile = New ValueStorage(New BinaryData(PathToFile));
			Data.Volume = Catalogs.FileStorageVolumes.EmptyRef();
			Data.PathToFile = "";
		Else
			// Add to one of the volumes (where there is a vacant place).
			FileInformation = FileFunctionsService.AddFileToVolume(PathToFile, Data.AddingDate, String(Data.FileID), "");
			Data.StoredFile = Undefined;
			Data.Volume = FileInformation.Volume;
			Data.PathToFile = FileInformation.PathToFile;
		EndIf;
		
		Data.Write();
		If PathToOldFile <> Undefined Then
			DeleteFiles(PathToOldFile);
		EndIf;
		
		CommitTransaction();
		
		If OriginalDataArea <> Undefined Then
			CommonUse.SetSessionSeparation(True, OriginalDataArea);
		EndIf;
	Except
		RollbackTransaction();
		
		If OriginalDataArea <> Undefined Then
			CommonUse.SetSessionSeparation(True, OriginalDataArea);
		EndIf;
		
		Raise;
	EndTry;
		
EndProcedure

// Deletes file from cache.
//
// Parameters:
//  RefOrIdentifier - CatalogRef.SuppliedData or UUID.
//
Procedure DeleteProvidedDataFromCache(Val RefOrIdentifier) Export
	Var Data, FullPath;
	
	SetPrivilegedMode(True);
	
	If TypeOf(RefOrIdentifier) = Type("UUID") Then
		RefOrIdentifier = Catalogs.SuppliedData.FindByAttribute("FileID", RefOrIdentifier);
		If RefOrIdentifier.IsEmpty() Then
			Return;
		EndIf;
	EndIf;
	
	Data = RefOrIdentifier.GetObject();
	If Data = Undefined Then 
		Return;
	EndIf;
	
	If Data.FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
		FullPath = FileFunctionsService.FullPathOfVolume(Data.Volume) + Data.PathToFile;
		DeleteFiles(FullPath);
	EndIf;
	
	Delete = New ObjectDeletion(RefOrIdentifier);
	Delete.DataExchange.Load = True;
	Delete.Write();
	
EndProcedure

// Receives data descriptor from cache.
//
// Parameters:
//  RefOrIdentifier - CatalogRef.SuppliedData or UUID.
//  ByXDTO - Boolean. IN which form values should be returned.
//
Function HandleSuppliedDataFromCache(Val RefOrIdentifier, Val ByXDTO = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	If TypeOf(RefOrIdentifier) = Type("UUID") Then
		Suffix = "CatalogSuppliedData.FileID = &FileID";
		Query.SetParameter("FileID", RefOrIdentifier);
	Else
		Suffix = "CatalogSuppliedData.Ref = &Ref";
		Query.SetParameter("Ref", RefOrIdentifier);
	EndIf;
	
	Query.Text = "SELECT
    |	CatalogStandardData.FileID,
    |	CatalogStandardData.AddingDate,
    |	CatalogStandardData.DataKind,
    |	CatalogStandardData.DataCharacteristics.(
    |		Value,
    |		Characteristic)
    |FROM
  	|  Catalog.SuppliedData AS CatalogStandardData
  	|	WHERE " + Suffix;
	 
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		Return ?(ByXDTO, GetXDTODescriptor(Selection), GetDescriptor(Selection));
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns binary data of the attached file.
//
// Parameters:
//  RefOrIdentifier - CatalogRef.SuppliedData 
//                       or UUID - file identifier.
//
// Returns:
//  BinaryData.
//
Function ProvidedDataFromCache(Val RefOrIdentifier) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(RefOrIdentifier) = Type("UUID") Then
		RefOrIdentifier = Catalogs.SuppliedData.FindByAttribute("FileID", RefOrIdentifier);
		If RefOrIdentifier.IsEmpty() Then
			Return Undefined;
		EndIf;
	EndIf;
	
	FileObject = RefOrIdentifier.GetObject();
	If FileObject = Undefined Then
		Return Undefined;
	EndIf;
	
	If FileObject.FileStorageType = Enums.FileStorageTypes.InInfobase Then
		Return FileObject.StoredFile.Get();
	Else
		FullPath = FileFunctionsService.FullPathOfVolume(FileObject.Volume) + FileObject.PathToFile;
		
		Try
			Return New BinaryData(FullPath)
		Except
			// Record in the event log.
			ErrorInfo = ErrorTextOnFileReceiving(ErrorInfo(), RefOrIdentifier);
			WriteLogEvent(
				NStr("en='Supplied data.Receiving file from volume';ru='Поставляемые данные.Получение файла из тома'", 
				CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.SuppliedData,
				RefOrIdentifier,
				ErrorInfo);
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='An error occurred while opening file: file is not found on server.
		|Contact your administrator.
		|
		|File: ""%1.%2"".';ru='Ошибка открытия файла: файл не найден на сервере.
		|Обратитесь к администратору.
		|
		|Файл: ""%1.%2"".'"),
				FileObject.Description,
				FileObject.Extension);
		EndTry;
	EndIf;
	
EndFunction

// Checks whether there are data with the specified key characteristics in cache.
//
// Parameters:
//   Handle   - XDTOObject Descriptor.
//
// Returns:
//  Boolean.
//
Function IsInCache(Val Handle) Export
	
	Filter = New Array;
	For Each Characteristic IN Handle.Properties.Property Do
		If Characteristic.IsKey Then
			Filter.Add(New Structure("Code, Value", Characteristic.Code, Characteristic.Value));
		EndIf;
	EndDo;
	
	Query = DataQueryByNames(Handle.DataType, Filter);
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Returns array of references to data that match the criteria you specify.
//
// Parameters:
//  DataKind - String. 
//  Filter - Collection. Items should contain fields Code (string) and Value (string).
//
// Return
//    value Array
//
Function RefOfProvidedDataFromCache(Val DataKind, Val Filter = Undefined) Export
	
	Query = DataQueryByNames(DataKind, Filter);
	Return Query.Execute().Unload().UnloadColumn("SuppliedData");
	
EndFunction

// Receive data by the specified conditions.
//
// Parameters:
//  DataKind - String. 
//  Filter - Collection. Items should contain fields Code (string) and Value (string).
//  ByXDTO - Boolean. IN which form values should be returned.
//
// Return
//    value ObjectXDTO of the ArrayOfDescriptor type or.
//    Structures array with fields "DataKind, AddingDate,
//    FileIdentifier, Characteristics", where Characteristics - array of structures with fields "Code, Value, Key".
//   To receive file itself, you should call GetSuppliedDataFromCache.
//
//
Function DescriptorsProvidedDataFromCache(Val DataKind, Val Filter = Undefined, Val ByXDTO = False) Export
	Var Query, QueryResult, Selection, Descriptors, Result;
	
	Query = DataQueryByNames(DataKind, Filter);
		
	Query.Text = "SELECT
    |	CatalogStandardData.FileID,
    |	CatalogStandardData.AddingDate,
    |	CatalogStandardData.DataKind,
    |	CatalogStandardData.DataCharacteristics.(
    |		Value,
    |		Characteristic)
    |FROM
  	|  Catalog.SuppliedData AS CatalogStandardData
  	|	WHERE CatalogStandardData.Ref IN (" + Query.Text + ")";
	 
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If ByXDTO Then
		Result = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"ArrayOfDescriptor"));
		Descriptors = Result.Descriptor;
	Else
		Result = New Array();
		Descriptors = Result;
	EndIf;

	While Selection.Next()  Do
		Message = ?(ByXDTO, GetXDTODescriptor(Selection), GetDescriptor(Selection));
		Descriptors.Add(Message);
	EndDo;		
	
	Return Result;
	
EndFunction	

// Returns user presentation of the supplied data descriptor.
// It can be used during messages output to the events log monitor.
//
// Parameters:
//  DescriptorXDTO - ObjectXDTOD of the Descriptor type or structure with fields.
//  	"DataKind, AddingDate, FileIdentifier,
//    	Characteristics" where Characteristics - structures array with fields "Code, Value".
//
// Returned
//  value String
//
Function GetDataDescription(Val Handle) Export
	Var Definition, Characteristic;
	
	If Handle = Undefined Then
		Return "";
	EndIf;
	
	If TypeOf(Handle) = Type("XDTODataObject") Then
		Definition = Handle.DataType;
		For Each Characteristic IN Handle.Properties.Property Do
			Definition = Definition
				+ ", " + Characteristic.Code + ": " + Characteristic.Value;
		EndDo; 
		
		Definition = Definition + 
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en=', added: %1 (%2), it is recommended to import: %3 (%2)';ru=', добавлен: %1 (%2), рекомендовано загрузить: %3 (%2)'"), 
			ToLocalTime(Handle.CreationDate, SessionTimeZone()), TimeZonePresentation(SessionTimeZone()), 
			ToLocalTime(Handle.RecommendedUpdateDate));
	Else
		Definition = Handle.DataKind;
		For Each Characteristic IN Handle.Characteristics Do
			Definition = Definition
				+ ", " + Characteristic.Code + ": " + Characteristic.Value;
		EndDo; 
		
		Definition = Definition + 
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en=', added: %1 (%2)';ru=', добавлен: %1 (%2)'"), 
			ToLocalTime(Handle.AddingDate, SessionTimeZone()), TimeZonePresentation(SessionTimeZone()));
	EndIf;
		
	Return Definition;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////////
// Update information in the data areas.

// Returns data areas list to which supplied data has not been copied yet.
//
// IN case it is the first function call, the set of available fields is returned.
// Only unprocessed areas will be returned during on
// subsequent call during the crash recovery. After you copy data to area, you should call AreaProcessed.
//
// Parameters:
//  FileID - UUID - supplied data file identifier.
//  ProcessorCode - String
//  IncludingUndivided - Boolean - if True, area with -1 code is added to all areas.
// 
Function AreasRequiredProcessing(Val FileID, Val ProcessorCode, Val IncludingUnshared = False) Export
	
	RecordSet = InformationRegisters.DemandDataProcessorSuppliedDataAreas.CreateRecordSet();
	RecordSet.Filter.FileID.Set(FileID);
	RecordSet.Filter.ProcessorCode.Set(ProcessorCode);
	RecordSet.Read();
	If RecordSet.Count() = 0 Then
		Query = New Query;
		Query.Text = "SELECT
		               |	&FileID AS FileID,
		               |	&ProcessorCode AS ProcessorCode,
		               |	DataAreas.DataAreaAuxiliaryData AS DataArea
		               |FROM
		               |	InformationRegister.DataAreas AS DataAreas
		               |WHERE
		               |	DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)";
		Query.SetParameter("FileID", FileID);
		Query.SetParameter("ProcessorCode", ProcessorCode);
		RecordSet.Load(Query.Execute().Unload());
		
		If IncludingUnshared Then
			CommonRates = RecordSet.Add();
			CommonRates.FileID = FileID;
			CommonRates.ProcessorCode = ProcessorCode;
			CommonRates.DataArea = -1;
		EndIf;
		
		RecordSet.Write();
	EndIf;
	Return RecordSet.UnloadColumn("DataArea");
EndFunction	

// Deletes area from the list of unprocessed ones. Disables session separation (if it
// is enabled) as writing to the undivided register is prohibited when the separation is enabled.
//
// Parameters:
//  FileID - UUID of the supplied data file.
//  ProcessorCode - String
//  DataArea - Number, identifier of the processed area.
// 
Procedure AreaProcessed(Val FileID, Val ProcessorCode, Val DataArea) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		CommonUse.SetSessionSeparation(False);
	EndIf;
	
	RecordSet = InformationRegisters.DemandDataProcessorSuppliedDataAreas.CreateRecordSet();
	RecordSet.Filter.FileID.Set(FileID);
	If DataArea <> Undefined Then
		RecordSet.Filter.DataArea.Set(DataArea);
	EndIf;
	RecordSet.Filter.ProcessorCode.Set(ProcessorCode);
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// Declares the SuppliedData subsystem events:
//
// Server events:
//   OnDefineSuppliedDataHandlers.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// Register the handlers of supplied data.
	//
	// When getting notification of new common data accessibility the procedure is called.
	// AvailableNewData modules registered through GetSuppliedDataHandlers.
	// Descriptor is passed to the procedure - XDTOObject Descriptor.
	// 
	// IN case if AvailableNewData sets the argument to Import in value is true, the data is importing, the handle and the path to the file with data pass to a procedure.
	// ProcessNewData. File will be automatically deleted after procedure completed.
	// If the file was not specified in the service manager - The argument value is Undefined.
	//
	// Parameters: 
	//   Handlers, ValueTable - The table for adding handlers. 
	//       Columns:
	//        DataKind, string - the code of data kind processed by the handler.
	//        HandlersCode, row(20) - it will be used during restoring data processing after the failure.
	//        Handler,  CommonModule - the module that contains the following procedures:
	//          AvailableNewData(Handle,
	//          Import) Export ProcessNewData(Handle,
	//          PathToFile) Export DataProcessingCanceled(Handle) Export
	//
	// Syntax:
	// Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	//
	// For use in other libraries.
	//
	// (Same as SuppliedDataOverridable.GetSuppliedDataHandlers).
	//
	ServerEvents.Add("StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData");
	
EndProcedure

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.MessageExchange\OnDefenitionMessagesFeedHandlers"].Add(
				"SuppliedData");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
				"SuppliedData");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function NewProxyOnServiceManager()
	
	URL = Constants.InternalServiceManagerURL.Get();
	UserName = Constants.ServiceManagerOfficeUserName.Get();
	UserPassword = Constants.ServiceManagerOfficeUserPassword.Get();

	ServiceAddress = URL + "/ws/SuppliedData?wsdl";
	
	Return CommonUse.WSProxy(ServiceAddress, 
		"http://www.1c.ru/SaaS/1.0/WS", "SuppliedData", , UserName, UserPassword);
		
EndFunction

// Receive query that returns references to data with the specified characteristics.
//
// Parameters:
//  DataKind      - String.
//  Characteristics - collection containing structures Code(string).
//                   AND Value(string).
//
// Returns:
//   Query
Function DataQueryByNames(Val DataKind, Val Characteristics)
	If Characteristics = Undefined Or Characteristics.Count() = 0 Then
		Return QueryForNameTypeData(DataKind);
	Else
		Return QueryByNamesCharacteristics(DataKind, Characteristics);
	EndIf;
EndFunction

Function QueryForNameTypeData(Val DataKind)
	Query = New Query();
	Query.Text = "SELECT
	|	SuppliedData.Ref AS SuppliedData
	|FROM
	|	Catalog.SuppliedData AS SuppliedData
	|WHERE
	|	SuppliedData.DataKind = &DataKind";
	Query.SetParameter("DataKind", DataKind);
	Return Query;
	
EndFunction

Function QueryByNamesCharacteristics(Val DataKind, Val Characteristics)
// SELECT Ref
// IN Characteristics
// WHERE (CharacteristicName = '' AND CharacteristicValue = '') OR ..(N)
// GROUP BY IdData
// HAVING Count(*) = N
	Query = New Query();
	Query.Text = 
	"SELECT
	|	StandardDataDataCharacteristics.Ref AS SuppliedData
	|FROM
	|	Catalog.SuppliedData.DataCharacteristics AS StandardDataDataCharacteristics
	|WHERE 
	|	StandardDataDataCharacteristics.Ref.DataKind = &DataKind AND (";
	Counter = 0;
	For Each Characteristic IN Characteristics Do
		If Counter > 0 Then
			Query.Text = Query.Text + " OR ";
		EndIf; 
		
		Query.Text = Query.Text + "( CAST(DataCharacteristicSuppliedData.Value AS String(150)) = &Value" + Counter + "
		| AND SuppliedDataDataCharacteristics.Characteristic = &Code" + Counter + ")";
		Query.SetParameter("Value" + Counter, Characteristic.Value);
		Query.SetParameter("Code" + Counter, Characteristic.Code);
		Counter = Counter + 1;
	EndDo;
	Query.Text = Query.Text + ")
	|GROUP BY
	|DataCharacteristicSuppliedData.Ref
	|HAVING
	|Quantity(*) = &Quantity";
	Query.SetParameter("Count", Counter);
	Query.SetParameter("DataKind", DataKind);
	Return Query;
	
EndFunction

// Convert selection results to XDTO object.
//
// Parameters:
//  Selection      - SelectionFromQueryResult Selection of query that
//                 contains information about data update.
//
Function GetXDTODescriptor(Selection)
	Handle = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"Descriptor"));
	Handle.DataType = Selection.DataKind;
	Handle.CreationDate = Selection.AddingDate;
	Handle.FileGUID = Selection.FileID;
	Handle.Properties = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"ArrayOfProperty"));
	CharacteristicsSelection = Selection.DataCharacteristics.Select();
	While CharacteristicsSelection.Next() Do
		Characteristic = CreateObject(XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData",
				"Property"));
		Characteristic.Code = CharacteristicsSelection.Characteristic;
		Characteristic.Value = CharacteristicsSelection.Value;
		Characteristic.IsKey = True;
		Handle.Properties.Property.Add(Characteristic);
	EndDo; 
	Return Handle;
	
EndFunction

Function GetDescriptor(Val Selection)
	Var Handle, CharacteristicsSelection, Characteristic;
	
	Handle = New Structure("DataKind, AddingDate, FileID, Characteristics");
	Handle.DataKind = Selection.DataKind;
	Handle.AddingDate = Selection.AddingDate;
	Handle.FileID = Selection.FileID;
	Handle.Characteristics = New Array();
	
	CharacteristicsSelection = Selection.DataCharacteristics.Select();
	While CharacteristicsSelection.Next() Do
		Characteristic = New Structure("Code, Value, Key");
		Characteristic.Code = CharacteristicsSelection.Characteristic;
		Characteristic.Value = CharacteristicsSelection.Value;
		Characteristic.Key = True;
		Handle.Characteristics.Add(Characteristic);
	EndDo; 
	
	Return Handle;
	
EndFunction

Function CreateObject(Val MessageType)
	
	Return XDTOFactory.Create(MessageType);
	
EndFunction

Function ErrorTextOnFileReceiving(Val ErrorInfo, Val File)
	
	ErrorInfo = BriefErrorDescription(ErrorInfo);
	
	If File <> Undefined Then
		ErrorInfo = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1
		|
		|Ref to file: ""%2"".';ru='%1
		|
		|Ссылка на файл: ""%2"".'"),
			ErrorInfo,
			GetURL(File) );
	EndIf;
	
	Return ErrorInfo;
	
EndFunction

// Compares whether characteristics set received from the descriptor meets the filter criteria.
//
// Parameters:
//  Filter - Collection of objects with the Code and Value fields.
//  Characteristics - Collection of objects with the Code and Value fields.
//
// Return
//   value Boolean
//
Function CharacteristicsCoincide(Val Filter, Val Characteristics) Export

	For Each StringFilter IN Filter Do
		StringFound = False;
		For Each Characteristic IN Characteristics Do 
			If Characteristic.Code = StringFilter.Code Then
				If Characteristic.Value = StringFilter.Value Then
					StringFound = True;
				Else 
					Return False;
				EndIf;
			EndIf;
		EndDo;
		If Not StringFound Then
			Return False;
		EndIf;
	EndDo;
		
	Return True;
	
EndFunction	

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Fills in the match of methods names and their aliases for call from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name for call, for example, SaaSOperations.ClearDataArea.
//    You can specify Undefined as a value, in this case, it is
// considered that name matches the alias.
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("SuppliedDataMessagesMessageHandler.ImportData");
	
EndProcedure

// Gets the list of message handlers that handle library subsystems.
// 
// Parameters:
//  Handlers - ValueTable - see field content in MessageExchange.NewMessageHandlersTable.
// 
Procedure OnDefenitionMessagesFeedHandlers(Handlers) Export
	
	MessagesSuppliedDataMessageHandler.GetMessageChannelHandlers(Handlers);
	
EndProcedure

#EndRegion
