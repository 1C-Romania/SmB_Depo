////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Includes saved parameters, used by the subsystem.
Function ProgramEventsParameters() Export
	
	SetPrivilegedMode(True);
	SavedParameters = StandardSubsystemsServer.ApplicationWorkParameters(
		"ServiceEventsParameters");
	SetPrivilegedMode(False);
	
	StandardSubsystemsServer.CheckForUpdatesApplicationWorkParameters(
		"ServiceEventsParameters",
		"EventsHandlers");
	
	If Not SavedParameters.Property("EventsHandlers") Then
		StandardSubsystemsServerCall.OnGettingErrorHandlersEvents();
	EndIf;
	
	SetPrivilegedMode(True);
	SavedParameters = StandardSubsystemsServer.ApplicationWorkParameters(
		"ServiceEventsParameters");
	SetPrivilegedMode(False);
	
	ParameterPresentation = "";
	
	If Not SavedParameters.Property("EventsHandlers") Then
		ParameterPresentation = NStr("en='EVENT HANDLERS';ru='Обработчики событий'");
	EndIf;
	
	If ValueIsFilled(ParameterPresentation) Then
		
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Information base updating error.
		|Service events parameter is
		|not filled in: %1';ru='Ошибка обновления информационной базы.
		|Не заполнен параметр
		|служебных событий: ""%1"".'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
			ParameterPresentation);
	EndIf;
	
	Return SavedParameters;
	
EndFunction

// Returns the description of all
// configuration libraries including the description of configuration itself.
//
Function SubsystemDescriptions() Export
	
	SubsystemModules = New Array;
	SubsystemModules.Add("InfobaseUpdateSSL");
	
	ConfigurationSubsystemsOverridable.OnAddSubsystems(SubsystemModules);
	
	ConfigurationDescriptionFound = False;
	SubsystemDescriptions = New Structure;
	SubsystemDescriptions.Insert("Order",  New Array);
	SubsystemDescriptions.Insert("ByNames", New Map);
	
	AllRequiredSubsystems = New Map;
	
	For Each ModuleName IN SubsystemModules Do
		
		Description = NewSubsystemDetails();
		Module = CommonUse.CommonModule(ModuleName);
		Module.OnAddSubsystem(Description);
		
		If Description.Name = "StandardSubsystems" Then
			// <PROPERTIES ONLY FOR STANDARD SUBSYSTEMS LIBRARY>
			Description.AddInternalEvents            = True;
			Description.AdditHandlersOfficeEvents = True;
		EndIf;
		
		CommonUseClientServer.Validate(SubsystemDescriptions.ByNames.Get(Description.Name) = Undefined,
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while
		|preparing subsystems descriptions: in the subsystem description (see the procedure %1.OnAddSubsystem)
		|subsystem name %2 is specified which has already been registered.';ru='Ошибка при подготовке описаний подсистем: в описании подсистемы (см. процедуру %1.ПриДобавленииПодсистемы) указано имя подсистемы ""%2"", которое уже зарегистрировано ранее.'"),
				ModuleName, Description.Name));
		
		If Description.Name = Metadata.Name Then
			ConfigurationDescriptionFound = True;
			Description.Insert("IsConfiguration", True);
		Else
			Description.Insert("IsConfiguration", False);
		EndIf;
		
		Description.Insert("MainServerModule", ModuleName);
		
		SubsystemDescriptions.ByNames.Insert(Description.Name, Description);
		// Setting of the subsystems order considering the main modules adding order.
		SubsystemDescriptions.Order.Add(Description.Name);
		// Batch of all required subsystems.
		For Each RequiredSubsystem IN Description.RequiredSubsystems Do
			If AllRequiredSubsystems.Get(RequiredSubsystem) = Undefined Then
				AllRequiredSubsystems.Insert(RequiredSubsystem, New Array);
			EndIf;
			AllRequiredSubsystems[RequiredSubsystem].Add(Description.Name);
		EndDo;
	EndDo;
	
	// Check of the main configuration description.
	If ConfigurationDescriptionFound Then
		Description = SubsystemDescriptions.ByNames[Metadata.Name];
		
		CommonUseClientServer.Validate(Description.Version = Metadata.Version,
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while
		|preparing subsystems descriptions: version %2 of the configuration %1 (see the procedure %3.OnAddSubsystem)
		|does not match configuration version in metadata %4.';ru='Ошибка при подготовке описаний подсистем: версия ""%2"" конфигурации ""%1"" (см. процедуру %3.ПриДобавленииПодсистемы) не совпадает с версией конфигурации в метаданных ""%4"".'"),
				Description.Name,
				Description.Version,
				Description.MainServerModule,
				Metadata.Version));
	Else
		Description = NewSubsystemDetails();
		Description.Insert("Name",    Metadata.Name);
		Description.Insert("Version", Metadata.Version);
		Description.Insert("IsConfiguration", True);
		SubsystemDescriptions.ByNames.Insert(Description.Name, Description);
		SubsystemDescriptions.Order.Add(Description.Name);
	EndIf;
	
	// Check if all required subsystems are present.
	For Each KeyAndValue IN AllRequiredSubsystems Do
		If SubsystemDescriptions.ByNames.Get(KeyAndValue.Key) = Undefined Then
			DependentSubsystems = "";
			For Each DependentSubsystem IN KeyAndValue.Value Do
				DependentSubsystems = Chars.LF + DependentSubsystem;
			EndDo;
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred while
		|preparing subsystems descriptions: subsystem %1 is not found required for subsystems: %2';ru='Ошибка при
		|подготовке описаний подсистем: не найдена подсистема ""%1"" требуемая для подсистем: %2.'"),
				KeyAndValue.Key,
				DependentSubsystems);
		EndIf;
	EndDo;
	
	// Setting of the subsystems order considering dependencies.
	For Each KeyAndValue IN SubsystemDescriptions.ByNames Do
		Name = KeyAndValue.Key;
		Order = SubsystemDescriptions.Order.Find(Name);
		For Each RequiredSubsystem IN KeyAndValue.Value.RequiredSubsystems Do
			OrderRequiredSubsystem = SubsystemDescriptions.Order.Find(RequiredSubsystem);
			If Order < OrderRequiredSubsystem Then
				Interdependence = SubsystemDescriptions.ByNames[RequiredSubsystem
					].RequiredSubsystems.Find(Name) <> Undefined;
				If Interdependence Then
					NewOrder = OrderRequiredSubsystem;
				Else
					NewOrder = OrderRequiredSubsystem + 1;
				EndIf;
				If Order <> NewOrder Then
					SubsystemDescriptions.Order.Insert(NewOrder, Name);
					SubsystemDescriptions.Order.Delete(Order);
					Order = NewOrder - 1;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	// Configuration description shift to the end of the array.
	IndexOf = SubsystemDescriptions.Order.Find(Metadata.Name);
	If SubsystemDescriptions.Order.Count() > IndexOf + 1 Then
		SubsystemDescriptions.Order.Delete(IndexOf);
		SubsystemDescriptions.Order.Add(Metadata.Name);
	EndIf;
	
	For Each KeyAndValue IN SubsystemDescriptions.ByNames Do
		
		KeyAndValue.Value.RequiredSubsystems =
			New FixedArray(KeyAndValue.Value.RequiredSubsystems);
		
		SubsystemDescriptions.ByNames[KeyAndValue.Key] =
			New FixedStructure(KeyAndValue.Value);
	EndDo;
	
	SubsystemDescriptions.Order  = New FixedArray(SubsystemDescriptions.Order);
	SubsystemDescriptions.ByNames = New FixedMap(SubsystemDescriptions.ByNames);
	
	Return New FixedStructure(SubsystemDescriptions);
	
EndFunction

// Returns the array of server event handlers descriptions.
Function HandlersOfServerEvent(Event, Service = False) Export
	
	PreparedHandlers = PreparedByHandlersOfServerEvents(Event, Service);
	
	If PreparedHandlers = Undefined Then
		// Cache autoupdate. Update reused values is required.
		StandardSubsystemsServerCall.OnGettingErrorHandlersEvents();
		RefreshReusableValues();
		// Retry to get event handlers.
		PreparedHandlers = PreparedByHandlersOfServerEvents(Event, Service, False);
	EndIf;
	
	Return PreparedHandlers;
	
EndFunction

// Returns the match of “functional” subsystems names to True value.
// Clear the Include in command interface check box in “functional” subsystem.
//
Function NamesSubsystems() Export
	
	names = New Map;
	InsertSubordinateSubsystemsNames(names, Metadata);
	
	Return New FixedMap(names);
	
EndFunction

// Returns metadata objects list that are
// used in DIB only when an initial subordinate node image is being created.
// Objects list is composed for all subsystems for which the event is defined.
// StandardSubsystems.BasicFunctionality\OnGetExchangePlanInitialImageObjects.
//
//  Returns:
// Type: FixedMatch. Key - metadata object; Value - True.
//
Function ObjectsOfPrimaryImage() Export
	
	Result = New Map;
	
	Objects = New Array;
	
	// Receive objects of an initial image.
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.BasicFunctionality\OnGetPrimaryImagePlanExchangeObjects");
	For Each Handler IN EventHandlers Do
		
		Handler.Module.OnGetPrimaryImagePlanExchangeObjects(Objects);
		
	EndDo;
	
	For Each Object IN Objects Do
		
		Result.Insert(Object.FullName(), True);
		
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

// Returns the list of DIB exchange plans.
// If configuration works in the
// service model, then it returns the list of DIB separated exchange plans.
//
Function DIBExchangePlans() Export
	
	Result = New Array;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		For Each ExchangePlan IN Metadata.ExchangePlans Do
			
			If ExchangePlan.DistributedInfobase
				AND CommonUseReUse.IsSeparatedMetadataObject(ExchangePlan.FullName(),
					CommonUseReUse.MainDataSeparator())
				Then
				
				Result.Add(ExchangePlan.Name);
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each ExchangePlan IN Metadata.ExchangePlans Do
			
			If ExchangePlan.DistributedInfobase Then
				
				Result.Add(ExchangePlan.Name);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the match of predefined values names to references to them.
// 
// Parameters:
//  FullMetadataObjectName - String, for
//                               example, Catalog.ProductsAndServicesKinds, Only
//                               tables with predefined items are supported:
//                               - Catalogs,
//                               - Characteristics kinds plans,
//                               - Accounts charts,
//                               - Charts of calculation kinds.
// 
// Returns:
//  Match
//   where Key     - String - predefined
//   name, Value - Predefined reference.
//
Function ReferencesByNamesOfPredefined(FullMetadataObjectName) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CurrentTable.Ref AS Ref,
	|	CurrentTable.PredefinedDataName AS PredefinedDataName
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Predefined = TRUE";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", FullMetadataObjectName);
	
	Selection = Query.Execute().Select();
	
	PredefinedValues = New Map;
	
	While Selection.Next() Do
		PredefinedName = Selection.PredefinedDataName;
		PredefinedValues.Insert(PredefinedName, Selection.Ref);
	EndDo;
	
	Return PredefinedValues;
	
EndFunction

// Returns True if the privileged
// mode is set during the start using the UsePrivilegedMode parameter.
//
// It is supported only during
// the client applications start (external connection is not supported).
//
Function PrivilegedModeInstalledOnLaunch() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.ClientParametersOnServer.Get(
		"PrivilegedModeInstalledOnLaunch") = True;
	
EndFunction

// Only for internal use.
Function ApplicationWorkParameters(ConstantName) Export
	
	Parameters = Constants[ConstantName].Get().Get();
	
	If TypeOf(Parameters) <> Type("Structure") Then
		Parameters = New Structure;
	EndIf;
	
	Return New FixedStructure(Parameters);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Receive identifier by the metadata object and vice versa.

// Only for internal use.
Function MetadataObjectID(FullMetadataObjectName) Export
	
	StandardSubsystemsReUse.CatalogMetadataObjectsIDsCheckUse(True);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("DescriptionFull", FullMetadataObjectName);
	Query.Text =
	"SELECT
	|	IDs.Ref AS Ref,
	|	IDs.MetadataObjectKey,
	|	IDs.FullName
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	IDs.FullName = &DescriptionFull
	|	AND Not IDs.DeletionMark";
	
	Exporting = Query.Execute().Unload();
	If Exporting.Count() = 0 Then
		// If identifier is not found by the full name, the full name may have been specified with an error.
		If Metadata.FindByFullName(FullMetadataObjectName) = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectID().
		|
		|Metadata object is not found
		|by the full name: %1';ru='Ошибка при выполнении функции ОбщегоНазначения.ИдентификаторОбъектаМетаданных().
		|
		|Объект метаданных
		|не найден по полному имени: ""%1"".'"),
				FullMetadataObjectName);
		EndIf;
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectID().
		|
		|For the metadata
		|object %1 an
		|identifier is not found in the Metadata objects identifiers catalog.';ru='Ошибка при выполнении функции ОбщегоНазначения.ИдентификаторОбъектаМетаданных().
		|
		|Для объекта
		|метаданных ""%1""
		|не найден идентификатор в справочнике ""Идентификаторы объектов метаданных"".'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
			FullMetadataObjectName);
	ElsIf Exporting.Count() > 1 Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectID().
		|
		|For the metadata
		|object %1 several
		|identifiers are found in the Metadata objects identifiers catalog.';ru='Ошибка при выполнении функции ОбщегоНазначения.ИдентификаторОбъектаМетаданных().
		|
		|Для объекта
		|метаданных ""%1""
		|найдено несколько идентификаторов в справочнике ""Идентификаторы объектов метаданных"".'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
			FullMetadataObjectName);
	EndIf;
	
	// Check the match of metadata object key to the metadata object full name.
	CheckResult = Catalogs.MetadataObjectIDs.MetadataObjectKeyCorrespondsDescriptionFull(Exporting[0]);
	If CheckResult.NotCorresponds Then
		If CheckResult.MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectID().
		|
		|For the metadata
		|object %1 an identifier is found in
		|the Metadata objects identifiers catalog that corresponds to the removed metadata object.';ru='Ошибка при выполнении функции ОбщегоНазначения.ИдентификаторОбъектаМетаданных().
		|
		|Для объекта
		|метаданных ""%1"" найден идентификатор в
		|справочнике ""Идентификаторы объектов метаданных"", которому соответствует удаленный объект метаданных.'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
				FullMetadataObjectName);
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred during the execution of CommonUse function.MetadataObjectID().
		|
		|For the metadata
		|object %1 an identifier is found in
		|the Metadata objects identifiers catalog that corresponds to another metadata object %2.';ru='Ошибка при выполнении функции ОбщегоНазначения.ИдентификаторОбъектаМетаданных().
		|
		|Для объекта
		|метаданных ""%1"" найден идентификатор в
		|справочнике ""Идентификаторы объектов метаданных"", который соответствует другому объекту метаданных ""%2"".'")
			+ StandardSubsystemsServer.SpecificationOfErrorParametersWorkApplicationForDeveloper(),
				FullMetadataObjectName,
				CheckResult.MetadataObject);
		EndIf;
	EndIf;
	
	Return Exporting[0].Ref;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Use the MetadataObjectsIDs catalog.

// Only for internal use.
Function DisableCatalogMetadataObjectIDs() Export
	
	Use = Not CommonUse.GeneralBasicFunctionalityParameters(
		).DisableCatalogMetadataObjectIDs;
	
	If Use Then
		Return False;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants")
	 OR CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors")
	 OR CommonUse.SubsystemExists("StandardSubsystems.ReportsMailing")
	 OR CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		Raise
			NStr("en='Unable to disable the Metadata
		|objects identifiers catalog if any of
		|the following
		|subsystems is
		|used: -
		|ReportVariants, - AdditionalReportsAndDataProcessors, - ReportsMail, - AccessManagement.';ru='Невозможно отключить справочник Идентификаторы объектов метаданных,
		|если используется любая из следующих подсистем:
		|- ВариантыОтчетов,
		|- ДополнительныеОтчетыИОбработки,
		|- РассылкаОтчетов,
		|- УправлениеДоступом.'");
	EndIf;
	
	Return True;
	
EndFunction

// Only for internal use.
Function CatalogMetadataObjectsIDsCheckUse(CheckUpdate = False) Export
	
	Catalogs.MetadataObjectIDs.CheckUse();
	
	If CheckUpdate Then
		Catalogs.MetadataObjectIDs.DataUpdated(True);
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// To update the MetadataObjectsIDs catalog.

// Only for internal use.
Function RenamingTableForCurrentVersion() Export
	
	Return Catalogs.MetadataObjectIDs.RenamingTableForCurrentVersion();
	
EndFunction

// Only for internal use.
Function MetadataObjectCollectionProperties() Export
	
	Return Catalogs.MetadataObjectIDs.MetadataObjectCollectionProperties();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with predefined data.

// It receives the predefined item reference by its full name.
//  Details - see CommonUseClientServer.PredefinedItem();
//
Function PredefinedItem(Val FullPredefinedName) Export
	
	PredefinedName = Upper(FullPredefinedName);
	
	Point = Find(PredefinedName, ".");
	CollectionName = Left(PredefinedName, Point - 1);
	PredefinedName = Mid(PredefinedName, Point + 1);
	
	Point = Find(PredefinedName, ".");
	TableName = Left(PredefinedName, Point - 1);
	PredefinedName = Mid(PredefinedName, Point + 1);
	
	QueryText = "SELECT ALLOWED TOP 1 Ref FROM &FullTableName WHERE PredefinedDataName = &PredefinedName";
	QueryText = StrReplace(QueryText, "&FullTableName", CollectionName + "." + TableName);
	
	Query = New Query(QueryText);
	Query.SetParameter("PredefinedName", PredefinedName);

	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		Return Result.Unload()[0].Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

Function NewSubsystemDetails()
	
	Description = New Structure;
	Description.Insert("Name",    "");
	Description.Insert("Version", "");
	Description.Insert("RequiredSubsystems", New Array);
	
	// Property is set automatically.
	Description.Insert("IsConfiguration", False);
	
	// Name of the library main module.
	// Can be empty for configuration.
	Description.Insert("MainServerModule", "");
	
	//  <PROPERTIES ONLY FOR STANDARD SUBSYSTEMS LIBRARY>
	
	Description.Insert("AddEvents",            False);
	Description.Insert("AdditHandlersEvent", False);
	
	//  AddInternalEvents - Boolean - if True, the standard procedure will be called.
	//                         OnAddServiceEvents(ClientEvents,
	//                         ServerEvents) from the main library module.
	// 
	//  AdditHandlersOfficeEvents - Boolean - if True, the standard procedure will be called.
	//                         OnAddServiceEventsHandlers(ClientHandlers,
	//                         Server Handlers) from the library main module.
	
	Description.Insert("AddInternalEvents",            False);
	Description.Insert("AdditHandlersOfficeEvents", False);
	
	Return Description;
	
EndFunction

Procedure InsertSubordinateSubsystemsNames(names, ParentSubsystem, All = False, ParentSubsystemName = "")
	
	For Each CurrentSubsystem IN ParentSubsystem.Subsystems Do
		
		If CurrentSubsystem.IncludeInCommandInterface AND Not All Then
			Continue;
		EndIf;
		
		CurrentSubsystemName = ParentSubsystemName + CurrentSubsystem.Name;
		names.Insert(CurrentSubsystemName, True);
		
		If CurrentSubsystem.Subsystems.Count() = 0 Then
			Continue;
		EndIf;
		
		InsertSubordinateSubsystemsNames(names, CurrentSubsystem, All, CurrentSubsystemName + ".");
	EndDo;
	
EndProcedure

Function PreparedByHandlersOfServerEvents(Event, Service = False, FirstTry = True)
	
	Parameters = StandardSubsystemsReUse.ProgramEventsParameters(
		).EventsHandlers.AtServer;
	
	If Service Then
		Handlers = Parameters.ServiceEventHandlers.Get(Event);
	Else
		Handlers = Parameters.EventsHandlers.Get(Event);
	EndIf;
	
	If FirstTry AND Handlers = Undefined Then
		Return Undefined;
	EndIf;
	
	If Handlers = Undefined Then
		If Service Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Server service event is not found %1.';ru='Не найдено серверное служебное событие ""%1"".'"), Event);
		Else
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Server event is not found %1.';ru='Не найдено серверное событие ""%1"".'"), Event);
		EndIf;
	EndIf;
	
	Array = New Array;
	
	For Each Handler IN Handlers Do
		Item = New Structure;
		Module = Undefined;
		If FirstTry Then
			Try
				Module = CommonUse.CommonModule(Handler.Module);
			Except
				Return Undefined;
			EndTry;
		Else
			Module = CommonUse.CommonModule(Handler.Module);
		EndIf;
		Item.Insert("Module",     Module);
		Item.Insert("Version",     Handler.Version);
		Item.Insert("Subsystem", Handler.Subsystem);
		Array.Add(New FixedStructure(Item));
	EndDo;
	
	Return New FixedArray(Array);
	
EndFunction

#EndRegion
