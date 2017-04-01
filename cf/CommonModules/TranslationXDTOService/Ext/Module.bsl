////////////////////////////////////////////////////////////////////////////////
// Subsystem "XDTO translation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Returns the message  version  description. Return value is used
// for transfer as the InitialVersionsDetails and DetailsOfResultingVersions parameters.
// Procedures FindTranslationChains().
//
// Parameters:
//  Number - String, version number of messages
//  in the format RR.{P|PP}.ZZ.SS, Package - String, namespace of message version.
//
// Returns:
//  Structure(Number, Package).
//
Function GenerateVersionDescription(Number = Undefined, Package = Undefined) Export
	
	Return New Structure("Number, Package", Number, Package);
	
EndFunction // GenerateVersionDescription()

// Forms a user friendly presentation of message interface version.
//
// Parameters:
//  VersionDescription - Structure, result of the GenerateVersionDescription() function execution.
//
// Return value: string.
//
Function GeneratePresentationVersions(VersionDescription) Export
	
	Result = "";
	
	If ValueIsFilled(VersionDescription.Number) Then
		
		Result = VersionDescription.Number;
		
	EndIf;
	
	If ValueIsFilled(VersionDescription.Package) Then
		
		PackagePresentation = "{" + VersionDescription.Package + "}";
		
		If Not IsBlankString(Result) Then
			Result = Result + " (" +  PackagePresentation + ")";
		Else
			Result = PackagePresentation;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// If there are several message translation chains from one version
// to another, it returns the most optimum version (containing minimum stages).
//
// Parameters:
//  TranslationChains - Array received as a result of the FindTranslationChain() function work.
//
// Returns:
//  ValueTable - array item, translation chain containing minimum stages.
Function SelectTranslationChain(Val TranslationChains) Export
	
	If TranslationChains.Count() = 1 Then
		Return TranslationChains.Get(0);
	Else
		
		CurrentChoice = Undefined;
		
		For Each ChainOfBroadcast IN TranslationChains Do
			
			If CurrentChoice = Undefined Then
				CurrentChoice = ChainOfBroadcast;
			Else
				CurrentChoice = ?(ChainOfBroadcast.Count() < CurrentChoice.Count(),
						ChainOfBroadcast, CurrentChoice);
			EndIf;
			
		EndDo;
		
		Return CurrentChoice;
		
	EndIf;
	
EndFunction

// For an internal use.
Function GetInterfaceMessages(Val Message) Export
	
	MessageSourcePackages = GetPackagesMessages(Message);
	RegisteredInterfaces = MessageInterfacesSaaS.GetInterfacesAreSentMessages();
	
	For Each PackageSourceMessages IN MessageSourcePackages Do
		
		InterfaceMessages = RegisteredInterfaces.Get(PackageSourceMessages);
		If ValueIsFilled(InterfaceMessages) Then
			
			Return New Structure("ProgramInterface, TargetNamespace", InterfaceMessages, PackageSourceMessages);
			
		EndIf;
		
	EndDo;
	
EndFunction

// For an internal use.
Function ExecuteBroadcast(Val InitialObject, Val InitialVersionsDetails, Val DetailsOfResultingVersions) Export
	
	TransmissionChainOfInterface = GetBroadcastChain(
			InitialVersionsDetails,
			DetailsOfResultingVersions);
	If TransmissionChainOfInterface = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Translation handler from %1 version to the %2 version is not registered in the configuration!';ru='В конфигурации не зарегистрирован обработчик трансляции из версии %1 в версию %2!'"),
			GeneratePresentationVersions(InitialVersionsDetails),
			GeneratePresentationVersions(DetailsOfResultingVersions));
	Else
		
		InterfaceTranslationTable = New ValueTable();
		InterfaceTranslationTable.Columns.Add("Key", New TypeDescription("String"));
		InterfaceTranslationTable.Columns.Add("Value", New TypeDescription("CommonModule"));
		InterfaceTranslationTable.Columns.Add("VersionByNumber", New TypeDescription("Number"));
		
		For Each StageBroadcastInterface IN TransmissionChainOfInterface Do
			
			StageTable = InterfaceTranslationTable.Add();
			FillPropertyValues(StageTable, StageBroadcastInterface);
			Version = StageBroadcastInterface.Value.ResultingVersion();
			Level = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Version, ".");
			Iterator = 0;
			VersionByNumber = 0;
			For Each Digit IN Level Do
				
				VersionByNumber = VersionByNumber + (Number(Digit) * Pow(1000, Level.Count() - Iterator));
				Iterator = Iterator + 1;
				
			EndDo;
			StageTable.VersionByNumber = VersionByNumber;
			
		EndDo;
		
		InterfaceTranslationTable.Sort("VersionByNumber Desc");
		
	EndIf;
	
	For Each StageBroadcastInterface IN InterfaceTranslationTable Do
		
		Handler = StageBroadcastInterface.Value;
		
		PerformDefaultProcessing = True;
		Handler.BeforeTranslation(InitialObject, PerformDefaultProcessing);
		
		If PerformDefaultProcessing Then
			RulesBroadcastInterfaces = GenerateRulesBroadcastInterfaces(InitialObject, StageBroadcastInterface);
			InitialObject = TransmitObject(InitialObject, RulesBroadcastInterfaces);
		Else
			InitialObject = Handler.BroadcastMessage(InitialObject);
		EndIf;
		
	EndDo;
	
	Return InitialObject;
	
EndFunction

// Returns the execution chain of handlers of translation between interface message versions.
//  If several available chains of translation between message interface
//  versions are registred in the configuration - returns the optimum version (containing a smaller number of stages).
//
// Parameters:
//  InitialVersionsDetails - Structure, the translated version
//      original description which is sufficient for unambiguous definition of the handlers in the translation table.
//    Structure fields:
//      Number - String, the original version of messages
//      in format RR.{P|PP}.ZZ.SS, Package - String, the namespace of the
//  message original version, DetailsOfResultingVersions - Structure, description of the
//      resulting version to which it is required
//      to translate a message, sufficient unambiguous definition of the handlers in the translation table.
//    Structure fields:
//      Number - String, the message resulting version
//      in format RR.{P|PP}.ZZ.SS,
//      Package - String, the namespace of
//        the message resulting version.
//
// Returns:
//  FixedMap:
//    Key - Resulting message version package.
//    Value - CommonModule, translation handler.
//
Function GetBroadcastChain(Val InitialVersionsDetails, Val DetailsOfResultingVersions) Export
	
	TranslationHandlersRegistered = GetTranslationHandlers();
	
	TranslationChains = New Array();
	FindTranslationChain(
			TranslationHandlersRegistered,
			InitialVersionsDetails,
			DetailsOfResultingVersions,
			TranslationChains);
	
	If TranslationChains.Count() = 0 Then
		Return Undefined;
	Else
		Return SelectTranslationChain(TranslationChains);
	EndIf;
	
EndFunction

// Returns the packages included in the source package dependencies.
//
// Parameters:
//  ObjectMessagePackage - String, the namespace of package for
//    which the dependencies are searched.
//
// Returns:
//  FixedArray, items - String.
//
Function GetPackageDependencies(Val ObjectMessagePackage) Export
	
	Result = New Array();
	PackageDependencies = XDTOFactory.packages.Get(ObjectMessagePackage).Dependencies;
	For Each Dependence IN PackageDependencies Do
		
		PackageDependenciesMessage = Dependence.NamespaceURI;
		Result.Add(PackageDependenciesMessage);
		NestedDependencies = GetPackageDependencies(PackageDependenciesMessage);
		CommonUseClientServer.SupplementArray(Result, NestedDependencies, True);
		
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// For an internal use.
Function TransmitObject(Val Object, Val RulesBroadcastInterfaces)
	
	SourceObjectPackage = Object.Type().NamespaceURI;
	TransmissionChainOfInterface = RulesBroadcastInterfaces.Get(SourceObjectPackage);
	
	If TransmissionChainOfInterface = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to define the translation handler for the (%1) package, impossible to execute the standard translation for this property processing';ru='Не удалось определить обработчик трансляции для пакета {%1}, невозможно выполнение стандартной трансляции для обработки данного свойства'"), 
			SourceObjectPackage);
	EndIf;
	
	If TransmissionChainOfInterface.Count() > 0 Then
		
		For Each IterationBroadcast IN TransmissionChainOfInterface Do
			
			Handler = IterationBroadcast.Value;
			
			PerformDefaultProcessing = True;
			Handler.BeforeTranslation(Object, PerformDefaultProcessing);
			
			If PerformDefaultProcessing Then
				Object = StandardProcessing(Object, Handler.PackageResultingVersions(), RulesBroadcastInterfaces);
			Else
				Object = Handler.BroadcastMessage(Object);
			EndIf;
			
		EndDo;
		
	Else
		
		// If there are no iterations in the translation chain, it means that
		// the version is not changed, and it is necessary just to copy the values of the original object properties into the resulting object.
		Object = StandardProcessing(Object, Object.Type().NamespaceURI, RulesBroadcastInterfaces);
		
	EndIf;
	
	Return Object;
	
EndFunction

// For an internal use.
Function StandardProcessing(Val Object, Val PackageResultObject, Val RulesBroadcastInterfaces)
	
	SourceObjectType = Object.Type();
	If SourceObjectType.NamespaceURI = PackageResultObject Then
		ResultedObjectType = SourceObjectType;
	Else
		ResultedObjectType = XDTOFactory.Type(PackageResultObject, SourceObjectType.Name);
		If ResultedObjectType = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to complete standard processing of the %1 translation type into the %2 package: the %1 type does not exist in the %2 package.';ru='Не удалось выполнить стандартную обработку трансляции типа %1 в пакет %2: тип %1 не существует в пакете %2!'"),
				"{" + SourceObjectType.NamespaceURI + "}" + SourceObjectType.Name,
				"{" + PackageResultObject + "}");
		EndIf;
	EndIf;
		
	ResultObject = XDTOFactory.Create(ResultedObjectType);
	PropertiesOfSourceObject = Object.Properties();
	
	For Each Property IN ResultedObjectType.Properties Do
		
		PropertyOfOriginal = SourceObjectType.Properties.Get(Property.LocalName);
		If PropertyOfOriginal = Undefined Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to complete the standard processing of the %1 type conversion into the %2 type: the %3 property is not defined for the %1 type!';ru='Не удалось выполнить стандартную обработку конвертации типа %1 в тип %2: свойство %3 не определено для типа %1!'"),
				"{" + SourceObjectType.NamespaceURI + "}" + SourceObjectType.Name,
				"{" + ResultedObjectType.NamespaceURI + "}" + ResultedObjectType.Name,
				Property.LocalName);
			
		EndIf;
		
	EndDo;
	
	For Each Property IN SourceObjectType.Properties Do
		
		TranslatedProperty = ResultedObjectType.Properties.Get(Property.LocalName);
		If TranslatedProperty = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Failed to complete the standard processing of the %1 type conversion into the %2 type: the %3 property is not defined for the %2 type!';ru='Не удалось выполнить стандартную обработку конвертации типа %1 в тип %2: свойство %3 не определено для типа %2!'"),
				"{" + SourceObjectType.NamespaceURI + "}" + SourceObjectType.Name,
				"{" + ResultedObjectType.NamespaceURI + "}" + ResultedObjectType.Name,
				Property.LocalName);
		EndIf;
			
		If Object.IsSet(Property) Then
			
			If Property.UpperBound = 1 Then
				
				// XDTODataObject or XDTODataValue.
				TransmittedValue = Object.GetXDTO(Property);
				
				If TypeOf(TransmittedValue) = Type("XDTODataObject") Then
					ResultObject.Set(TranslatedProperty, TransmitObject(TransmittedValue, RulesBroadcastInterfaces));
				Else
					ResultObject.Set(TranslatedProperty, TransmittedValue);
				EndIf;
				
			Else
				
				// XDTOList
				TranslationList = Object.GetList(Property);
				
				For Iterator = 0 To TranslationList.Count() - 1 Do
					
					ItemOfList = TranslationList.GetXDTO(Iterator);
					
					If TypeOf(ItemOfList) = Type("XDTODataObject") Then
						ResultObject[Property.LocalName].Add(TransmitObject(ItemOfList, RulesBroadcastInterfaces));
					Else
						ResultObject[Property.LocalName].Add(ItemOfList);
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return ResultObject;
	
EndFunction

// For an internal use.
Function GenerateRulesBroadcastInterfaces(Val Message, Val IterationBroadcastInterface)
	
	RulesBroadcastInterfaces = New Map();
	
	MessageSourcePackages = New Array();
	PackagesResultMessages = New Array();
	
	MessageSourcePackages = GetPackagesMessages(Message);
	
	HandlerInterfaceTranslation = IterationBroadcastInterface.Value;
	
	PackagesResultMessages.Add(HandlerInterfaceTranslation.PackageResultingVersions());
	DependenciesPackageCorrespondent = GetPackageDependencies(HandlerInterfaceTranslation.PackageResultingVersions());
	CommonUseClientServer.SupplementArray(PackagesResultMessages, DependenciesPackageCorrespondent, True);
	
	RuleBroadcastInterface = New Map();
	RuleBroadcastInterface.Insert(IterationBroadcastInterface.Key, IterationBroadcastInterface.Value);
	
	RulesBroadcastInterfaces.Insert(HandlerInterfaceTranslation.SourceVersionPackage(), RuleBroadcastInterface);
	
	For Each PackageSourceMessages IN MessageSourcePackages Do
		
		ChainOfBroadcast = RulesBroadcastInterfaces.Get(PackageSourceMessages);
		
		If ChainOfBroadcast = Undefined Then
			
			If PackagesResultMessages.Find(PackageSourceMessages) <> Undefined Then
				
				// The same package is used both in the original interface version and in the resulting version.
				// It will not be necessary to translate it, it will be enough to shift the property values.
				RulesBroadcastInterfaces.Insert(PackageSourceMessages, New Map());
				
			Else
				
				// The package of original interface message version is not used in the resulting interface message version.
				// You need to determine to which package the resulting version should be translated.
				
				PossibleChains = New Array();
				For Each PackageResultingMessages IN PackagesResultMessages Do
					
					ChainPackage = GetBroadcastChain(
						GenerateVersionDescription(
								, PackageSourceMessages),
						GenerateVersionDescription(
								, PackageResultingMessages));
						
					If ValueIsFilled(ChainPackage) Then
						 PossibleChains.Add(ChainPackage);
					EndIf;
					
				EndDo;
				
				If PossibleChains.Count() > 0 Then
					
					UsedChain = SelectTranslationChain(PossibleChains);
					RulesBroadcastInterfaces.Insert(PackageSourceMessages, UsedChain);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return RulesBroadcastInterfaces;
	
EndFunction

// Returns the array filled with namespaces used in message.
//
// Parameters:
//  Message - XDTODataObject, the message for which
//    it is necessary to get the namespace packages list.
//
// Returns:
//  Array, items type: string.
//
Function GetPackagesMessages(Val Message)
	
	Result = New Array();
	
	// XDTO-object package
	ObjectMessagePackage = Message.Type().NamespaceURI;
	Result.Add(ObjectMessagePackage);
	
	// Dependencies of the XDTO-object package.
	Dependencies = GetPackageDependencies(ObjectMessagePackage);
	CommonUseClientServer.SupplementArray(Result, Dependencies, True);
	
	// XDTO-object properties
	PropertiesOfObject = Message.Properties();
	For Each Property IN PropertiesOfObject Do
		
		If Message.IsSet(Property) Then
			
			If Property.UpperBound = 1 Then
				
				PropertyValue = Message.GetXDTO(Property);
				
				If TypeOf(PropertyValue) = Type("XDTODataObject") Then
				
					PropertyPackages = GetPackagesMessages(PropertyValue);
					CommonUseClientServer.SupplementArray(Result, PropertyPackages, True);
					
				EndIf;
				
			Else
				
				PropertyList = Message.GetList(Property);
				Iterator = 0;
				
				For Iterator = 0 To PropertyList.Count() - 1 Do
					
					ItemOfList = PropertyList.GetXDTO(Iterator);
					
					If TypeOf(ItemOfList) = Type("XDTODataObject") Then
						
						PropertyPackages = GetPackagesMessages(ItemOfList);
						CommonUseClientServer.SupplementArray(Result, PropertyPackages, True);
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// The procedure is used for building the
// execution chain of translation handlers while translating the message from one version to another.
//
// Parameters:
//  TranslationHandlers - ValueTable the structure of which
//      was got using
//      the FormTranslationHandlersTable() function containing all message translation
//  handlers registered in the configuration, InitialVersionsDetails - Structure, the translated version
//      original description which is sufficient for unambiguous definition of the handlers in the translation table.
//    Structure fields:
//      Number - String, the original version of messages
//      in format RR.{P|PP}.ZZ.SS, Package - String, the namespace of the
//  message original version, DetailsOfResultingVersions - Structure, description of the
//      resulting version to which it is required
//      to translate a message, sufficient unambiguous definition of the handlers in the translation table.
//    Structure fields:
//      Number - String, the message resulting version
//      in format RR.{P|PP}.ZZ.SS,
//      Package - String, the namespace of
//        the
//  message resulting version, TranslationChains - Array, after the execution of procedure all possible message
//      translation chains will be placed into this parameter from the original version into the resulting version. The
//      array items are the fixed matches (key - the namespace
//      of the resulting version package, the value - CommonModule which
//  is the translation handler, CurrentChain - the service parameter which is used
//    in the recursive procedure execution should not be set during the first call.
//
Procedure FindTranslationChain(Val TranslationHandlers, Val InitialVersionsDetails, 
			Val DetailsOfResultingVersions, TranslationChains, CurrentChain = Undefined)
	
	Filter = New Structure();
	If ValueIsFilled(InitialVersionsDetails.Number) Then
		Filter.Insert("OriginalVersion", InitialVersionsDetails.Number);
	EndIf;
	If ValueIsFilled(InitialVersionsDetails.Package) Then
		Filter.Insert("SourceVersionPackage", InitialVersionsDetails.Package);
	EndIf;
	
	Branches = TranslationHandlers.Copy(Filter);
	For Each Branch IN Branches Do
		
		If CurrentChain = Undefined Then
			CurrentChain = New Map();
		EndIf;
		CurrentChain.Insert(Branch.PackageResultingVersions, Branch.Handler);
		
		If Branch.ResultingVersion = DetailsOfResultingVersions.Number
				OR Branch.PackageResultingVersions = DetailsOfResultingVersions.Package Then
			TranslationChains.Add(New FixedMap(CurrentChain));
		Else
			FindTranslationChain(TranslationHandlers,
					GenerateVersionDescription(
							, Branch.PackageResultingVersions),
					GenerateVersionDescription(
							DetailsOfResultingVersions.Number, DetailsOfResultingVersions.Package),
					TranslationChains, CurrentChain);
		EndIf;
			
	EndDo;
	
EndProcedure

// Table constructor of translation handlers.
Function CreateTableHandlersBroadcast()
	
	Result = New ValueTable();
	Result.Columns.Add("OriginalVersion");
	Result.Columns.Add("SourceVersionPackage");
	Result.Columns.Add("ResultingVersion");
	Result.Columns.Add("PackageResultingVersions");
	Result.Columns.Add("Handler");
	
	Return Result;
	
EndFunction

// Returns handlers table of translation messages existing in the configuration.
//
Function GetTranslationHandlers()
	
	Result = CreateTableHandlersBroadcast();
	ArrayOfHandlersOfTransition = New Array();
	
	MessagesTranslationHandlers = MessageInterfacesSaaS.GetTranslationHandlersMessages();
	CommonUseClientServer.SupplementArray(ArrayOfHandlersOfTransition, MessagesTranslationHandlers);
	
	TranslationXDTOOverridable.FillTranslationHandlersMessages(ArrayOfHandlersOfTransition);
	
	For Each Handler IN ArrayOfHandlersOfTransition Do
		
		RegistrationHandler = Result.Add();
		RegistrationHandler.OriginalVersion = Handler.OriginalVersion();
		RegistrationHandler.ResultingVersion = Handler.ResultingVersion();
		RegistrationHandler.SourceVersionPackage = Handler.SourceVersionPackage();
		RegistrationHandler.PackageResultingVersions = Handler.PackageResultingVersions();
		RegistrationHandler.Handler = Handler;
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
