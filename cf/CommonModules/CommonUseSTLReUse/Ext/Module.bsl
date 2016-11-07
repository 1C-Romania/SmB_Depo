#Region ServiceProgramInterface

// Returns the description of types containing primitive types.
//
// Return value: TypeDescription.
//
Function PrimitiveTypeDescription() Export
	
	Return New TypeDescription("Number, String, Boolean, Date, UUID, TypeDescription");
	
EndFunction

// Returns types description that contains all reference types of
// metadata objects existing in the configuration.
//
// Return value: TypeDescription.
//
Function ReferenceTypeDescription() Export
	
	AnyXDTORefTypeDescription = XDTOFactory.Create(XDTOFactory.Type("http://v8.1c.ru/8.1/data/core", "TypeDescription"));
	AnyXDTORefTypeDescription.TypeSet.Add(XDTOSerializer.WriteXDTO(New XMLExpandedName(
		"http://v8.1c.ru/8.1/data/enterprise/current-config", "AnyRef")));
	AnyRefTypeDescription = XDTOSerializer.ReadXDTO(AnyXDTORefTypeDescription);
	
	Return AnyRefTypeDescription;
	
EndFunction

// Checks if you use the 8 platform version.3.5.
//
// Return value: Boolean.
//
Function UsedPlatform8_3_5() Export
	
	Information = New SystemInfo();
	
	Return CommonUseClientServer.CompareVersions(Information.AppVersion, "8.3.5.1") >= 0;
	
EndFunction

// Checks if the platform mechanisms are available
// in the current configuration that are available only when you use 8 version platforms.3.5 with the
// Do not use compatibility mode.
//
// Return value: True if available.
//
Function AvailableMechanismsCompatibilityMode8_3_5() Export
	
	Return PlatformCompatibilityModeMechanismsAvailable("8.3.5.1");
	
EndFunction

// Checks if the platform mechanisms are available
// in the current configuration that are available only when you use 8 version platforms.3.3 with the
// Do not use compatibility mode.
//
// Return value: True if available.
//
Function AvailableMechanismsCompatibilityMode8_3_3() Export
	
	Return PlatformCompatibilityModeMechanismsAvailable("8.3.3.1");
	
EndFunction

// Returns the references of the route points of business processes.
//
// Return value: FixedMatch:
//                        * Key - Type - the
//                        BusinessProcessRoutePointRef type, * Value - String - name of the business process.
//
Function BusinessProcessesRoutePointsRefs() Export
	
	BusinessProcessesRoutePointsRefs = New Map();
	For Each BusinessProcess IN Metadata.BusinessProcesses Do
		BusinessProcessesRoutePointsRefs.Insert(Type("BusinessProcessRoutePointRef." + BusinessProcess.Name), BusinessProcess.Name);
	EndDo;
	
	Return New FixedMap(BusinessProcessesRoutePointsRefs);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function PlatformCompatibilityModeMechanismsAvailable(Val VersionNumber)
	
	CompatibilityModeVersion = CommonUseSTLReUse.PlatformCompatibilityModesVersions().Get(Metadata.CompatibilityMode);
	
	Return CommonUseClientServer.CompareVersions(CompatibilityModeVersion, VersionNumber) >= 0;
	
EndFunction

Function PlatformCompatibilityModesVersions() Export
	
	Information = New SystemInfo();
	PlatformVersion = Information.AppVersion;
	
	Result = New Map();
	
	Result.Insert(Metadata.ObjectProperties.CompatibilityMode["Version8_1"], "8.1.1.1");
	
	If CommonUseClientServer.CompareVersions(PlatformVersion, "8.2.13.1") >= 0 Then
		
		If CommonUseClientServer.CompareVersions(PlatformVersion, "8.2.16.1") >= 0 Then
			
			Result.Insert(Metadata.ObjectProperties.CompatibilityMode["Version8_2_13"], "8.2.13.1");
			
			If CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.1.1") >= 0 Then
				
				Result.Insert(Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"], "8.2.16.1");
				
				If CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.2.1") >= 0 Then
					
					Result.Insert(Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"], "8.3.1.1");
					
					If CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.3.1") >= 0 Then
						
						Result.Insert(Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"], "8.3.2.1");
						
						If CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.4.1") >= 0 Then
							
							Result.Insert(Metadata.ObjectProperties.CompatibilityMode["Version8_3_3"], "8.3.3.1");
							
							If CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.5.1") >= 0 Then
								
								Result.Insert(Metadata.ObjectProperties.CompatibilityMode["Version8_3_4"], "8.3.4.1");
								
								If CommonUseClientServer.CompareVersions(PlatformVersion, "8.3.6.1") >= 0 Then
									
									Result.Insert(Metadata.ObjectProperties.CompatibilityMode["Version8_3_5"], "8.3.5.1");
									
								Else
									
									Result.Insert(Metadata.ObjectProperties.CompatibilityMode["DontUse"], "8.3.5.1");
									
								EndIf;
								
							Else
								
								Result.Insert(Metadata.ObjectProperties.CompatibilityMode["DontUse"], "8.3.4.1");
								
							EndIf;
							
						Else
							
							Result.Insert(Metadata.ObjectProperties.CompatibilityMode["DontUse"], "8.3.3.1");
							
						EndIf;
						
					Else
						
						Result.Insert(Metadata.ObjectProperties.CompatibilityMode["DontUse"], "8.3.2.1");
						
					EndIf;
					
				Else
					
					Result.Insert(Metadata.ObjectProperties.CompatibilityMode["DontUse"], "8.3.1.1");
					
				EndIf;
				
			Else
				
				Result.Insert(Metadata.ObjectProperties.CompatibilityMode["DontUse"], "8.2.16.1");
				
			EndIf;
			
		Else
			
			Result.Insert(Metadata.ObjectProperties.CompatibilityMode["DontUse"], "8.2.13.1");
			
		EndIf;
		
	EndIf;
	
	Return New FixedMap(Result);
	
EndFunction

Function ConfigurationDataModelDescription() Export
	
	Model = New Map();
	
	FillModelBySubsystems(Model);
	FillModelByMetadataCollection(Model, "SessionParameters");
	FillModelByMetadataCollection(Model, "CommonAttributes");
	FillModelByMetadataCollection(Model, "ExchangePlans");
	FillModelByMetadataCollection(Model, "ScheduledJobs");
	FillModelByMetadataCollection(Model, "Constants");
	FillModelByMetadataCollection(Model, "Catalogs");
	FillModelByMetadataCollection(Model, "Documents");
	FillModelByMetadataCollection(Model, "Sequences");
	FillModelByMetadataCollection(Model, "DocumentJournals");
	FillModelByMetadataCollection(Model, "Enums");
	FillModelByMetadataCollection(Model, "ChartsOfCharacteristicTypes");
	FillModelByMetadataCollection(Model, "ChartsOfAccounts");
	FillModelByMetadataCollection(Model, "ChartsOfCalculationTypes");
	FillModelByMetadataCollection(Model, "InformationRegisters");
	FillModelByMetadataCollection(Model, "AccumulationRegisters");
	FillModelByMetadataCollection(Model, "AccountingRegisters");
	FillModelByMetadataCollection(Model, "CalculationRegisters");
	FillModelForRecalculation(Model);
	FillModelByMetadataCollection(Model, "BusinessProcesses");
	FillModelByMetadataCollection(Model, "Tasks");
	FillModelByMetadataCollection(Model, "ExternalDataSources");
	FillModelByFunctionalOptions(Model);
	FillModelBySeparators(Model);
	
	Return FixModel(Model);
	
EndFunction

Function MetadataClassesInConfigurationModel() Export
	
	CurrentMetadataClasses = New Structure();
	CurrentMetadataClasses.Insert("Subsystems", 1);
	CurrentMetadataClasses.Insert("SessionParameters", 2);
	CurrentMetadataClasses.Insert("CommonAttributes", 3);
	CurrentMetadataClasses.Insert("Constants", 4);
	CurrentMetadataClasses.Insert("Catalogs", 5);
	CurrentMetadataClasses.Insert("Documents", 6);
	CurrentMetadataClasses.Insert("Enums", 7);
	CurrentMetadataClasses.Insert("ChartsOfCharacteristicTypes", 8);
	CurrentMetadataClasses.Insert("ChartsOfAccounts", 9);
	CurrentMetadataClasses.Insert("ChartsOfCalculationTypes", 10);
	CurrentMetadataClasses.Insert("BusinessProcesses", 11);
	CurrentMetadataClasses.Insert("Tasks", 12);
	CurrentMetadataClasses.Insert("ExchangePlans", 13);
	CurrentMetadataClasses.Insert("DocumentJournals", 14);
	CurrentMetadataClasses.Insert("Sequences", 15);
	CurrentMetadataClasses.Insert("InformationRegisters", 16);
	CurrentMetadataClasses.Insert("AccumulationRegisters", 17);
	CurrentMetadataClasses.Insert("AccountingRegisters", 18);
	CurrentMetadataClasses.Insert("CalculationRegisters", 19);
	CurrentMetadataClasses.Insert("Recalculations", 20);
	CurrentMetadataClasses.Insert("ScheduledJobs", 21);
	CurrentMetadataClasses.Insert("ExternalDataSources", 22);
	
	Return New FixedStructure(CurrentMetadataClasses);
	
EndFunction

Function MetadataClasses()
	
	Return CommonUseSTLReUse.MetadataClassesInConfigurationModel();
	
EndFunction

Function DataModelGroup(Val Model, Val Class)
	
	Group = Model.Get(Class);
	
	If Group = Undefined Then
		Group = New Map();
		Model.Insert(Class, Group);
	EndIf;
	
	Return Group;
	
EndFunction

Procedure FillModelBySubsystems(Val Model)
	
	SubsystemsGroup = DataModelGroup(Model, MetadataClasses().Subsystems);
	
	For Each Subsystem IN Metadata.Subsystems Do
		FillModelBySubsystem(SubsystemsGroup, Subsystem);
	EndDo;
	
EndProcedure

Procedure FillModelBySubsystem(Val ModelGroup, Val Subsystem)
	
	FillModelByMetadataObject(ModelGroup, Subsystem, MetadataClasses().Subsystems);
	
	For Each NestedSubsystem IN Subsystem.Subsystems Do
		FillModelBySubsystem(ModelGroup, NestedSubsystem);
	EndDo;
	
EndProcedure

Procedure FillModelForRecalculation(Val Model)
	
	ModelGroup = DataModelGroup(Model, MetadataClasses().Recalculations);
	
	For Each CalculationRegister IN Metadata.CalculationRegisters Do
		
		For Each Recalculation IN CalculationRegister.Recalculations Do
			
			FillModelByMetadataObject(ModelGroup, Recalculation, MetadataClasses().Recalculations);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure FillModelByMetadataCollection(Val Model, Val CollectionName)
	
	Class = MetadataClasses()[CollectionName];
	ModelGroup = DataModelGroup(Model, Class);
	
	MetadataCollection = Metadata[CollectionName];
	For Each MetadataObject IN MetadataCollection Do
		FillModelByMetadataObject(ModelGroup, MetadataObject, Class);
	EndDo;
	
EndProcedure

Procedure FillModelByMetadataObject(Val ModelGroup, Val MetadataObject, Val Class)
	
	ObjectDescription = New Structure();
	ObjectDescription.Insert("DescriptionFull", MetadataObject.FullName());
	ObjectDescription.Insert("Presentation", MetadataObject.Presentation());
	ObjectDescription.Insert("Dependencies", New Map());
	ObjectDescription.Insert("FunctionalOptions", New Array());
	ObjectDescription.Insert("DataSeparation", New Structure());
	
	ModelGroup.Insert(MetadataObject.Name, ObjectDescription);
	
	FillModelByMetadataObjectDependencies(ObjectDescription.Dependencies, MetadataObject, Class);
	
EndProcedure

Procedure FillModelByMetadataObjectDependencies(Val ObjectDependencies, Val MetadataObject, Val Class)
	
	If Class = MetadataClasses().Constants Then
		
		FillModelByMetadataObjectDependencyTypes(ObjectDependencies, MetadataObject.Type);
		
	ElsIf (Class = MetadataClasses().Catalogs
			OR Class = MetadataClasses().Documents
			OR Class = MetadataClasses().ChartsOfCharacteristicTypes
			OR Class = MetadataClasses().ChartsOfAccounts
			OR Class = MetadataClasses().ChartsOfCalculationTypes
			OR Class = MetadataClasses().BusinessProcesses
			OR Class = MetadataClasses().Tasks
			OR Class = MetadataClasses().ExchangePlans) Then
		
		// Standard attributes
		For Each StandardAttribute IN MetadataObject.StandardAttributes Do
			FillModelByMetadataObjectDependencyTypes(ObjectDependencies, StandardAttribute.Type);
		EndDo;
		
		// Standard tabular sections
		If (Class = MetadataClasses().ChartsOfAccounts OR Class = MetadataClasses().ChartsOfCalculationTypes) Then
			
			For Each StandardTabularSection IN MetadataObject.StandardTabularSections Do
				For Each StandardAttrib IN StandardTabularSection.StandardAttributes Do
					FillModelByMetadataObjectDependencyTypes(ObjectDependencies, StandardAttribute.Type);
				EndDo;
			EndDo;
			
		EndIf;
		
		// Attributes
		For Each Attribute IN MetadataObject.Attributes Do
			FillModelByMetadataObjectDependencyTypes(ObjectDependencies, Attribute.Type);
		EndDo;
		
		// Tabular Sections
		For Each TabularSection IN MetadataObject.TabularSections Do
			// Standard attributes
			For Each StandardAttribute IN TabularSection.StandardAttributes Do
				FillModelByMetadataObjectDependencyTypes(ObjectDependencies, StandardAttribute.Type);
			EndDo;
			// Attributes
			For Each Attribute IN TabularSection.Attributes Do
				FillModelByMetadataObjectDependencyTypes(ObjectDependencies, Attribute.Type);
			EndDo;
		EndDo;
		
		If Class = MetadataClasses().Tasks Then
			
			// Addressing attributes
			For Each AddressingAttribute IN MetadataObject.AddressingAttributes Do
				FillModelByMetadataObjectDependencyTypes(ObjectDependencies, AddressingAttribute.Type);
			EndDo;
			
		EndIf;
		
		If Class = MetadataClasses().Documents Then
			
			// RegisterRecords
			For Each Register IN MetadataObject.RegisterRecords Do
				ObjectDependencies.Insert(Register.FullName(), True);
			EndDo;
			
		EndIf;
		
		If Class = MetadataClasses().ChartsOfCharacteristicTypes Then
			
			// Characteristics types
			FillModelByMetadataObjectDependencyTypes(ObjectDependencies, MetadataObject.Type);
			
			// Additional values of characteristics
			If MetadataObject.CharacteristicExtValues <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.CharacteristicExtValues.FullName(), True);
			EndIf;
			
		EndIf;
		
		If Class = MetadataClasses().ChartsOfAccounts Then
			
			// Accounting signs
			For Each AccountingFlag IN MetadataObject.AccountingFlags Do
				FillModelByMetadataObjectDependencyTypes(ObjectDependencies, AccountingFlag.Type);
			EndDo;
			
			// Types of ExtDimension
			If MetadataObject.ExtDimensionTypes <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.ExtDimensionTypes.FullName(), True);
			EndIf;
			
			// Extra dimension accounting signs
			For Each ExtraDimensionAccountingSign IN MetadataObject.ExtDimensionAccountingFlags Do
				FillModelByMetadataObjectDependencyTypes(ObjectDependencies, ExtraDimensionAccountingSign.Type);
			EndDo;
			
		EndIf;
		
		If Class = MetadataClasses().ChartsOfCalculationTypes Then
			
			// Basic calculation kinds
			For Each BasicCalculationKind IN MetadataObject.CalculationBasicKinds Do
				ObjectDependencies.Insert(BasicCalculationKind.FullName(), True);
			EndDo;
			
		EndIf;
		
	ElsIf Class = MetadataClasses().Sequences Then
		
		// Dimensions
		For Each Dimension IN MetadataObject.Dimensions Do
			FillModelByMetadataObjectDependencyTypes(ObjectDependencies, Dimension.Type);
		EndDo;
		
		// Incoming documents
		For Each IncomingDocument IN MetadataObject.Documents Do
			ObjectDependencies.Insert(IncomingDocument.FullName(), True);
		EndDo;
		
		// RegisterRecords
		For Each Register IN MetadataObject.RegisterRecords Do
			ObjectDependencies.Insert(Register.FullName(), True);
		EndDo;
		
	ElsIf (Class = MetadataClasses().InformationRegisters
			OR Class = MetadataClasses().AccumulationRegisters
			OR Class = MetadataClasses().AccountingRegisters
			OR Class = MetadataClasses().CalculationRegisters) Then
		
		// Standard attributes
		For Each StandardAttribute IN MetadataObject.StandardAttributes Do
			FillModelByMetadataObjectDependencyTypes(ObjectDependencies, StandardAttribute.Type);
		EndDo;
		
		// Dimensions
		For Each Dimension IN MetadataObject.Dimensions Do
			FillModelByMetadataObjectDependencyTypes(ObjectDependencies, Dimension.Type);
		EndDo;
		
		// Resources
		For Each Resource IN MetadataObject.Resources Do
			FillModelByMetadataObjectDependencyTypes(ObjectDependencies, Resource.Type);
		EndDo;
		
		// Attributes
		For Each Attribute IN MetadataObject.Attributes Do
			FillModelByMetadataObjectDependencyTypes(ObjectDependencies, Attribute.Type);
		EndDo;
		
		If Class = MetadataClasses().AccountingRegisters Then
			
			// Chart of accounts
			If MetadataObject.ChartOfAccounts <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.ChartOfAccounts.FullName(), True);
			EndIf;
			
		EndIf;
		
		If Class = MetadataClasses().CalculationRegisters Then
			
			// Chart of calculation types
			If MetadataObject.ChartOfCalculationTypes <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.ChartOfCalculationTypes.FullName(), True);
			EndIf;
			
			// Schedule
			If MetadataObject.Schedule <> Undefined Then
				ObjectDependencies.Insert(MetadataObject.Schedule.FullName(), True);
			EndIf;
			
		EndIf;
		
	ElsIf Class = MetadataClasses().DocumentJournals Then
		
		For Each Document IN MetadataObject.RegisteredDocuments Do
			ObjectDependencies.Insert(Document.FullName(), True);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillModelByMetadataObjectDependencyTypes(Val Result, Val TypeDescription)
	
	If CommonUseSTL.IsRefsTypesSet(TypeDescription) Then
		Return;
	EndIf;
	
	For Each Type IN TypeDescription.Types() Do
		
		If CommonUseSTL.IsReferenceType(Type) Then
			
			Dependence = CommonUseSTL.MetadataObjectByTypeRefs(Type);
			
			If Result.Get(Dependence.FullName()) = Undefined Then
				
				Result.Insert(Dependence.FullName(), True);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillModelByFunctionalOptions(Val Model)
	
	For Each FunctionalOption IN Metadata.FunctionalOptions Do
		
		For Each ContentItem IN FunctionalOption.Content Do
			
			If ContentItem.Object = Undefined Then
				Continue;
			EndIf;
			
			ObjectDescription = CommonUseSTL.ConfigurationModelObjectProperties(Model, ContentItem.Object);
			
			If ObjectDescription <> Undefined Then
				ObjectDescription.FunctionalOptions.Add(FunctionalOption.Name);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure FillModelBySeparators(Val Model)
	
	// Fill by the content of the common attribute
	
	For Each CommonAttribute IN Metadata.CommonAttributes Do
		
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			
			UseCommonAttribute = Metadata.ObjectProperties.CommonAttributeUse.Use;
				AutoUseCommonAttribute = Metadata.ObjectProperties.CommonAttributeUse.Auto;
				CommonAttributeAutoUse = 
					(CommonAttribute.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
			
			For Each ContentItem IN CommonAttribute.Content Do
				
				If (CommonAttributeAutoUse AND ContentItem.Use = AutoUseCommonAttribute)
						OR ContentItem.Use = UseCommonAttribute Then
					
					ObjectDescription = CommonUseSTL.ConfigurationModelObjectProperties(Model, ContentItem.Metadata);
					
					If ContentItem.ConditionalSeparation <> Undefined Then
						ConditionalSeparatorItem = ContentItem.ConditionalSeparation.FullName();
					Else
						ConditionalSeparatorItem = "";
					EndIf;
					
					ObjectDescription.DataSeparation.Insert(CommonAttribute.Name, ConditionalSeparatorItem);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// Additionally the sequences that contain separated documents are considered to be separated
	
	For Each Sequence IN Metadata.Sequences Do
		
		If Sequence.Documents.Count() > 0 Then
			
			SequenceDescription = CommonUseSTL.ConfigurationModelObjectProperties(Model, Sequence);
			
			For Each Document IN Sequence.Documents Do
				
				DocumentDescription = CommonUseSTL.ConfigurationModelObjectProperties(Model, Document);
				
				For Each KeyAndValue IN DocumentDescription.DataSeparation Do
					
					SequenceDescription.DataSeparation.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
				EndDo;
				
				Break;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// Additionally the documents logs that contain separated documents are considered to be separated
	
	For Each DocumentJournal IN Metadata.DocumentJournals Do
		
		If DocumentJournal.RegisteredDocuments.Count() > 0 Then
			
			LogDescription = CommonUseSTL.ConfigurationModelObjectProperties(Model, DocumentJournal);
			
			For Each Document IN DocumentJournal.RegisteredDocuments Do
				
				DocumentDescription = CommonUseSTL.ConfigurationModelObjectProperties(Model, Document);
				
				For Each KeyAndValue IN DocumentDescription.DataSeparation Do
					
					LogDescription.DataSeparation.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
				EndDo;
				
				Break;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	// Additionally the recalculations that obey the separated calculation registers are considered to be separated
	
	For Each CalculationRegister IN Metadata.CalculationRegisters Do
		
		If CalculationRegister.Recalculations.Count() > 0 Then
			
			CalculationRegisterDescription = CommonUseSTL.ConfigurationModelObjectProperties(Model, CalculationRegister);
			
			For Each Recalculation IN CalculationRegister.Recalculations Do
				
				RecalculationDescription = CommonUseSTL.ConfigurationModelObjectProperties(Model, Recalculation);
				
				For Each KeyAndValue IN CalculationRegisterDescription.DataSeparation Do
					
					RecalculationDescription.DataSeparation.Insert(KeyAndValue.Key, KeyAndValue.Value);
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function FixModel(Val Model)
	
	If TypeOf(Model) = Type("Array") Then
		
		Result = New Array();
		For Each Item IN Model Do
			Result.Add(FixModel(Item));
		EndDo;
		Return New FixedArray(Result);
		
	ElsIf TypeOf(Model) = Type("Structure") Then
		
		Result = New Structure();
		For Each KeyAndValue IN Model Do
			Result.Insert(KeyAndValue.Key, FixModel(KeyAndValue.Value));
		EndDo;
		Return New FixedStructure(Result);
		
	ElsIf  TypeOf(Model) = Type("Map") Then
		
		Result = New Map();
		For Each KeyAndValue IN Model Do
			Result.Insert(KeyAndValue.Key, FixModel(KeyAndValue.Value));
		EndDo;
		Return New FixedMap(Result);
		
	Else
		
		Return Model;
		
	EndIf;
	
EndFunction


#EndRegion
