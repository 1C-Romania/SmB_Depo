////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of the general purpose.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Returns the flag showing that there are common attributes-separators in the configuration.
//
// Returns:
// Boolean.
//
Function IsSeparatedConfiguration() Export
	
	HasSeparators = False;
	For Each CommonAttribute IN Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			HasSeparators = True;
			Break;
		EndIf;
	EndDo;
	
	Return HasSeparators;
	
EndFunction

// Returns an array of separators existing in the configuration.
//
// Return value: FixedArray(Row) - array of common
//  attributes names that are separators.
//
Function ConfigurationSeparators() Export
	
	DelimitersArray = New Array;
	
	For Each CommonAttribute IN Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			DelimitersArray.Add(CommonAttribute.Name);
		EndIf;
	EndDo;
	
	Return New FixedArray(DelimitersArray);
	
EndFunction

// Returns general attribute content with the specified name.
//
// Parameters:
// Name - String - Common attribute name.
//
// Returns:
// CommonAttributeContent.
//
Function CommonAttributeContent(Val Name) Export
	
	Return Metadata.CommonAttributes[Name].Content;
	
EndFunction

// Returns the flag showing that the metadata object is used in the common attributes-separators.
//
// Parameters:
// MetadataObjectName - String.
// Delimiter - name of the common attribute-separator and the metadata object is checked whether it was separated by it.
//
// Returns:
// Boolean.
//
Function IsSeparatedMetadataObject(Val MetadataObjectName, Val Delimiter) Export
	
	Return CommonUse.IsSeparatedMetadataObject(MetadataObjectName, Delimiter);
	
EndFunction

// Returns the name of the common attribute that is the common data separator.
//
// Return value: String.
//
Function MainDataSeparator() Export
	
	Result = "";
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.BasicFunctionalitySaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		Result = ModuleSaaSOperations.MainDataSeparator();
	EndIf;
	
	Return Result;
	
EndFunction

// Returns name of common attribute that is helper data separator.
//
// Return value: String.
//
Function SupportDataSplitter() Export
	
	Result = "";
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.BasicFunctionalitySaaS") Then
		ModuleSaaSOperations = CommonUse.CommonModule("SaaSOperations");
		Result = ModuleSaaSOperations.SupportDataSplitter();
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the flag showing that the conditional separator is enabled.
// Returns False if there is a call in the undivided configuration.
//
Function DataSeparationEnabled() Export
	
	Return CommonUseReUse.IsSeparatedConfiguration() AND GetFunctionalOption("SaaS");
	
EndFunction

// Returns the flag showing that it is possible to call the separated data from the current session.
// Returns True if there is a call in the undivided configuration.
//
// Returns:
// Boolean.
//
Function CanUseSeparatedData() Export
	
	Return Not CommonUseReUse.DataSeparationEnabled() OR CommonUse.UseSessionSeparator();
	
EndFunction

// Returns the XSLTransformation object created from the common
// layout with the passed name.
//
// Parameters:
// CommonTemplateName - String - common layout name of the
// BinaryData type containing XSL conversion file.
//
// Returns:
// XSLTransform - object XSLTransform.
//
Function GetXSLTransformFromCommonTemplate(Val CommonTemplateName) Export
	
	TemplateData = GetCommonTemplate(CommonTemplateName);
	TransformFileName = GetTempFileName("xsl");
	TemplateData.Write(TransformFileName);
	
	Transform = New XSLTransform;
	Transform.LoadFromFile(TransformFileName);
	
	Try
		DeleteFiles(TransformFileName);
	Except
		WriteLogEvent(NStr("en='Receiving XSL';ru='Получение XSL'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Transform;
	
EndFunction

// Defines if the session is run with or without the separator.
//
// Returns:
// Boolean.
//
Function SessionWithoutSeparator() Export
	
	Return InfobaseUsers.CurrentUser().DataSeparation.Count() = 0;
	
EndFunction

// Returns the type of server platform.
//
// Returns:
//   PlatformType; Undefined.
//
Function ServerPlatformType() Export
	
	ServerPlatformTypeAsString = StandardSubsystemsServerCall.ServerPlatformTypeAsString();
	
	If ServerPlatformTypeAsString = "Linux_x86" Then
		Return PlatformType.Linux_x86;
		
	ElsIf ServerPlatformTypeAsString = "Linux_x86_64" Then
		Return PlatformType.Linux_x86_64;
		
	ElsIf ServerPlatformTypeAsString = "Windows_x86" Then
		Return PlatformType.Windows_x86;
		
	ElsIf ServerPlatformTypeAsString = "Windows_x86_64" Then
		Return PlatformType.Windows_x86_64;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Defines the current mode of application work.
//   Specifically, it is used in
//   the application settings panels to hide the specialized interfaces intended not for all work modes.
//   
// Returns:
//   Structure - Settings that describe the current user rights and the application work current mode.
//     According to rights:
//       * ThisIsSystemAdministrator   - Boolean - True if there is an infobase administration right.
//       * ThisIsApplicationAdministrator - Boolean - True if there is an access to all
//                                              “applied” data of the infobase.
//     According to the operation modes of the base:
//       * ServiceModel   - Boolean - True if there are separators in the configuration and they are conditionally enabled.
//       * Local       - Boolean - True if the configuration works in the regular mode (neither in the service
//                                    model, nor in the offline work place).
//       * Offline      - Boolean - True if configuration works in AWP mode (offline work place).
//       * File        - Boolean - True if the configuration  works in the file mode.
//       * ClientServer - Boolean - True if the configuration works in the client-server mode.
//       * LocalFile        - Boolean - True if the work is executed in the file mode.
//       * LocalClientServer - Boolean - True if work is in the regular client-server  mode.
//     By the functionality of the client part:
//       * ThisIsLinuxClient - Boolean - True if the client application is run managed by Linux OS.
//       * ThisIsWebClient   - Boolean - True if the client application is a Web-client.
//   
// Description:
//   Application settings panels include 5 interfaces:
//     - For the administrator of service in the user's data area (SA).
//     - For user administrator (UA).
//     - For administrator of local solution in the client-server mode (LCS).
//     - For the administrator of local solution in the file mode (LF).
//     - For administrator of offline work place (AWP).
//   
//   SA and UA interfaces are cut using hiding of groups
//     and form items for all roles except of the SystemAdministrator role.
//   
//   Service administrator logged in
//     to the data area should see the same settings
//     as the subscriber administrator together with the service settings (undivided).
//
Function ApplicationRunningMode() Export
	RunMode = New Structure;
	
	// Current user's rights.
	RunMode.Insert("IsApplicationAdministrator", Users.InfobaseUserWithFullAccess(, False, False)); // UA, SA, LCS, LF
	RunMode.Insert("ThisIsSystemAdministrator",   Users.InfobaseUserWithFullAccess(, True, False)); // SA, LCS, LF
	
	// Operation mode of the server.
	RunMode.Insert("SaaS", DataSeparationEnabled()); // SA, UA
	RunMode.Insert("Local",     GetFunctionalOption("WorkInLocalMode")); // LCS, LF
	RunMode.Insert("Standalone",    GetFunctionalOption("WorkInOfflineMode")); // AWS
	RunMode.Insert("File",        False); // SA, UA, LF
	RunMode.Insert("ClientServer", False); // SA, UA, LCS
	
	If CommonUse.FileInfobase() Then
		RunMode.File = True;
	Else
		RunMode.ClientServer = True;
	EndIf;
	
	RunMode.Insert("LocalFile",
		RunMode.Local AND RunMode.File); // LF
	RunMode.Insert("LocalClientServer",
		RunMode.Local AND RunMode.ClientServer); // LCS
	
	// Operation mode of the client.
	RunMode.Insert("IsLinuxClient", CommonUseClientServer.IsLinuxClient());
	RunMode.Insert("ThisIsWebClient",   CommonUseClientServer.ThisIsWebClient());
	
	Return RunMode;
EndFunction

#EndRegion

#Region ServiceApplicationInterface

// Returns a list of full names of all metadata
//  objects used in the common attribute-separator name of which is passed as the
//  Separator parameter value. It also returns metadata object properties values that can be required for its subsequent processor in the universal algorithm.
// Defines separation by the incoming documents for sequences and documents logs: to any of.
//
// Parameters:
//  Delimiter - String, common attribute name.
//
// Returns:
// FixedMap,
//  Key - String, full name
//  of the metadata object, Value - FixedStructure,
//    Name - String, name
//    of the metadata object, Separator - String, name of the delimeter
//    that separates the metadata object, ConditionalSeparation - String, full name of metadata object acting as
//      condition of metadata object separation use by the current separator.
//
Function SeparatedMetadataObjects(Val Delimiter) Export
	
	Result = New Map;
	
	// I. Enumerate the content of all common attributes.
	
	CommonAttributeMetadata = Metadata.CommonAttributes.Find(Delimiter);
	If CommonAttributeMetadata = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Common attribute %1 is not found in configuration!';ru='Общий реквизит %1 не обнаружен в конфигурации!'"), Delimiter);
	EndIf;
	
	If CommonAttributeMetadata.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
		
		CommonAttributeContent = CommonUseReUse.CommonAttributeContent(CommonAttributeMetadata.Name);
		
		UseCommonAttribute = Metadata.ObjectProperties.CommonAttributeUse.Use;
		AutoUseCommonAttribute = Metadata.ObjectProperties.CommonAttributeUse.Auto;
		CommonAttributeAutoUse = 
			(CommonAttributeMetadata.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
		
		For Each ContentItem IN CommonAttributeContent Do
			
			If (CommonAttributeAutoUse AND ContentItem.Use = AutoUseCommonAttribute)
				OR ContentItem.Use = UseCommonAttribute Then
				
				AdditionalInformation = New Structure("Name,Delimiter,ConditionalSeparation", ContentItem.Metadata.Name, Delimiter, Undefined);
				If ContentItem.ConditionalSeparation <> Undefined Then
					AdditionalInformation.ConditionalSeparation = ContentItem.ConditionalSeparation.FullName();
				EndIf;
				
				Result.Insert(ContentItem.Metadata.FullName(), New FixedStructure(AdditionalInformation));
				
				// It is additionally defined by the calculation registers whether subordinate recalculations are separated.
				If CommonUse.ThisIsCalculationRegister(ContentItem.Metadata) Then
					
					Recalculations = ContentItem.Metadata.Recalculations;
					For Each Recalculation IN Recalculations Do
						
						AdditionalInformation.Name = Recalculation.Name;
						Result.Insert(Recalculation.FullName(), New FixedStructure(AdditionalInformation));
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	Else
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Data separation is not used for the common attribute %1!';ru='Для общего реквизита %1 не используется разделение данных!'"), Delimiter);
		
	EndIf;
	
	// II. Define separation by the incoming documents for sequences and logs.
	
	// 1) Sequences. Enumeration with the checking of the first incoming document. If there are no documents, consider it to be separated.
	For Each SequenceMetadata IN Metadata.Sequences Do
		
		AdditionalInformation = New Structure("Name,Delimiter,ConditionalSeparation", SequenceMetadata.Name, Delimiter, Undefined);
		
		If SequenceMetadata.Documents.Count() = 0 Then
			
			MessagePattern = NStr("en='No document is included into the %1 sequence.';ru='В последовательность %1 не включено ни одного документа.'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, SequenceMetadata.Name);
			WriteLogEvent(NStr("en='Separated metadata objects receipt';ru='Получение разделенных объектов метаданных'", 
				CommonUseClientServer.MainLanguageCode()), EventLogLevel.Error, 
				SequenceMetadata, , MessageText);
			
			Result.Insert(SequenceMetadata.FullName(), New FixedStructure(AdditionalInformation));
			
		Else
			
			For Each DocumentMetadata IN SequenceMetadata.Documents Do
				
				AdditionalInformationFromDocument = Result.Get(DocumentMetadata.FullName());
				
				If AdditionalInformationFromDocument <> Undefined Then
					FillPropertyValues(AdditionalInformation, AdditionalInformationFromDocument, "Delimiter,ConditionalSeparation");
					Result.Insert(SequenceMetadata.FullName(), New FixedStructure(AdditionalInformation));
				EndIf;
				
				Break;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// 2) Logs. Enumeration with the checking of the first incoming document. If there are no documents, consider it to be separated.
	For Each DocumentJournalMetadata IN Metadata.DocumentJournals Do
		
		AdditionalInformation = New Structure("Name,Delimiter,ConditionalSeparation", DocumentJournalMetadata.Name, Delimiter, Undefined);
		
		If DocumentJournalMetadata.RegisteredDocuments.Count() = 0 Then
			
			MessagePattern = NStr("en='No one document is included to the log %1.';ru='В журнал %1 не включено ни одного документа.'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, DocumentJournalMetadata.Name);
			WriteLogEvent(NStr("en='Separated metadata objects receipt';ru='Получение разделенных объектов метаданных'", 
				CommonUseClientServer.MainLanguageCode()), EventLogLevel.Error, 
				DocumentJournalMetadata, , MessageText);
			
			Result.Insert(DocumentJournalMetadata.FullName(), New FixedStructure(AdditionalInformation));
			
		Else
			
			For Each DocumentMetadata IN DocumentJournalMetadata.RegisteredDocuments Do
				
				AdditionalInformationFromDocument = Result.Get(DocumentMetadata.FullName());
				
				If AdditionalInformationFromDocument <> Undefined Then
					FillPropertyValues(AdditionalInformation, AdditionalInformationFromDocument, "Delimiter,ConditionalSeparation");
					Result.Insert(DocumentJournalMetadata.FullName(), New FixedStructure(AdditionalInformation));
				EndIf;
				
				Break;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the versions cache data from the resource of the StorageValues type of ApplicationmaticInterfaceCache register.
//
// Parameters:
//   ID - String - identifier of cache record.
//   DataType     - EnumRef.ProgramInterfaceCacheDataTypes.
//   ReceivingParameters - String - parameters array serialized in XML for passing to cache update method.
//   ReturnOutdatedData - Boolean - check box definig whether
//      the data update is required in the cache before returning the value in case their aging fact is discovered.
//      True - always use data from cache if any False - expect
//      the update of cache data in case the fact of data aging is discovered.
//
// Returns:
//   Custom.
//
Function CacheVersionsData(Val ID, Val DataType, Val ReceivingParameters, Val UseObsoleteData = True) Export
	
	ReceivingParameters = CommonUse.ValueFromXMLString(ReceivingParameters);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	TableCache.UpdateDate AS UpdateDate,
		|	TableCache.Data AS Data,
		|	TableCache.DataType AS DataType
		|FROM
		|	InformationRegister.ProgramInterfaceCache AS TableCache
		|WHERE
		|	TableCache.ID = &ID
		|	AND TableCache.DataType = &DataType";
	Query.SetParameter("ID", ID);
	Query.SetParameter("DataType", DataType);
	
	BeginTransaction();
	Try
		// Not set a managed lock so other sessions can change the value until this transaction is active.
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	WantedUpdate = False;
	RequiredRereadData = False;
	
	If Result.IsEmpty() Then
		
		WantedUpdate = True;
		RequiredRereadData = True;
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		If CommonUse.VersionCacheRecordObsolete(Selection) Then
			WantedUpdate = True;
			RequiredRereadData = Not UseObsoleteData;
		EndIf;
	EndIf;
	
	If WantedUpdate Then
		
		RefreshInCurrentSession = CommonUse.FileInfobase() Or ExclusiveMode() 
			Or CommonUseClientServer.DebugMode();
		
		If RefreshInCurrentSession Then
			CommonUse.RefreshVersionCacheData(ID, DataType, ReceivingParameters);
			RequiredRereadData = True;
		Else
			JobMethodName = "CommonUse.UpdateVersionCacheData";
			DescriptionSchTask = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Versions cache update. %1 record identifier. Data type %2';ru='Обновление кэша версий. Идентификатор записи %1. Тип данных %2.'"),
				ID,
				DataType);
			JobParameters = New Array;
			JobParameters.Add(ID);
			JobParameters.Add(DataType);
			JobParameters.Add(ReceivingParameters);
			
			JobsFilter = New Structure;
			JobsFilter.Insert("MethodName", JobMethodName);
			JobsFilter.Insert("Description", DescriptionSchTask);
			JobsFilter.Insert("Status", BackgroundJobState.Active);
			
			Jobs = BackgroundJobs.GetBackgroundJobs(JobsFilter);
			If Jobs.Count() = 0 Then
				// Start new
				BackgroundJobs.Execute(JobMethodName, JobParameters, , DescriptionSchTask);
				// The job could have been terminated at once because of the data update by other job.
				Jobs = BackgroundJobs.GetBackgroundJobs(JobsFilter);
			EndIf;
		EndIf;
		
		If RequiredRereadData Then
			If Not RefreshInCurrentSession Then
				Try
					// Wait for completion
					BackgroundJobs.WaitForCompletion(Jobs);
				Except
					For Each OriginalTask IN Tasks Do
						Job = BackgroundJobs.FindByUUID(OriginalTask.UUID);
						If Job.Status <> BackgroundJobState.Failed Then
							Continue;
						EndIf;
						
						If Job.ErrorInfo <> Undefined Then
							WriteLogEvent(NStr("en='Refresh versions cache';ru='Обновление кэша версий'", CommonUseClientServer.MainLanguageCode()),
								EventLogLevel.Error,
								,
								,
								DetailErrorDescription(Job.ErrorInfo));
							Raise(BriefErrorDescription(Job.ErrorInfo));
						Else
							WriteLogEvent(NStr("en='Refresh versions cache';ru='Обновление кэша версий'", CommonUseClientServer.MainLanguageCode()),
								EventLogLevel.Error,
								,
								,
								DetailErrorDescription(ErrorInfo()));
							Raise(NStr("en='Unknown error occurred when updating the version cache.';ru='Неизвестная ошибка при выполнения задания обновления кэша версий'"));
						EndIf;
					EndDo;
					
					Raise(NStr("en='Unknown error when updating the versions cache';ru='Неизвестная ошибка при обновлении кэша версий'"));
				EndTry;
			EndIf;
			
			BeginTransaction();
			Try
				// Not set a managed lock to allow other sessions to change a value until this transaction is active.
				Result = Query.Execute();
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
			If Result.IsEmpty() Then
				MessagePattern = NStr("en='An error occurred while updating the versions cache. Data is not received."
"Record identifier:"
"%1 Data type: %2';ru='Ошибка при обновлении кэша версий. Данные не получены."
"Идентификатор"
"записи: %1 Тип данных: %2'");
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
					MessagePattern, ID, DataType);
					
				Raise(MessageText);
			EndIf;
			
			Selection = Result.Select();
			Selection.Next();
		EndIf;
		
	EndIf;
		
	Return Selection.Data.Get();
	
EndFunction

// Returns the WSDefinitions object created with the passed parameters.
//
// Parameters:
//  WSDLAddress - String - wsdl location.
//  UserName - String - user name for the website login.
//  Password - String - user's password.
//
// Note: cache is used while receiving definition
//  update of which is executed while changing the configuration version. If for the debugging it
//  is required to update the value in cache, earlier than this, you should delete it from the information register.
//  ApplicationInterfacesCache corresponding records.
//
Function WSDefinitions(Val WSDLAddress, Val UserName, Val Password) Export
	
	Return CommonUse.WSDefinitions(WSDLAddress, UserName, Password);
	
EndFunction

// Returns the WSProxy object created with the passed parameters.
//
// Parameters correspond to the constructor of the WSProxy object.
//
Function WSProxy(Val WSDLAddress, Val NamespaceURI, Val ServiceName,
	Val EndpointName, Val UserName, Val Password, Val Timeout) Export
	
	Return CommonUse.InternalWSProxy(WSDLAddress, NamespaceURI, ServiceName, 
		EndpointName, UserName, Password, Timeout);
	
EndFunction

// Parameters applied to items of the command interface associated with parametric functional options.
Function InterfaceOptions() Export
	
	InterfaceOptions = New Structure;
	Try
		CommonUseOverridable.OnDefiningFunctionalInterfaceOptionsParameters(InterfaceOptions);
	Except
		ErrorInfo = ErrorInfo();
		EventName = NStr("en='Interface setting';ru='Настройка интерфейса'", CommonUseClientServer.MainLanguageCode());
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred while receiving"
"interface options: %1';ru='При получении опций интерфейса"
"произошла ошибка: %1'"),
			DetailErrorDescription(ErrorInfo));
		WriteLogEvent(EventName, EventLogLevel.Error,,, ErrorText);
	EndTry;
	
	Return InterfaceOptions;
EndFunction

// Availability of metadata objects by functional options.
Function ObjectsByOptionsAvailability() Export
	Parameters = CommonUseReUse.InterfaceOptions();
	If TypeOf(Parameters) = Type("FixedStructure") Then
		Parameters = New Structure(Parameters);
	EndIf;
	
	ObjectsAvailability = New Map;
	For Each FunctionalOption IN Metadata.FunctionalOptions Do
		Value = -1;
		For Each Item IN FunctionalOption.Content Do
			If Value = -1 Then
				Value = GetFunctionalOption(FunctionalOption.Name, Parameters);
			EndIf;
			If Value = True Then
				ObjectsAvailability.Insert(Item.Object, True);
			Else
				If ObjectsAvailability[Item.Object] = Undefined Then
					ObjectsAvailability.Insert(Item.Object, False);
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	Return ObjectsAvailability;
EndFunction

#EndRegion
