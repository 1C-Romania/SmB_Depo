#Region ProgramInterface

// Checks if the transferred metadata object is the MetadataObjectConfiguration object.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsObjectMetadataConfiguration(Val MetadataObject) Export
	
	Return TypeOf(MetadataObject) = Type("ConfigurationMetadataObject");
	
EndFunction

// Checks if the transferred metadata object is a subsystem.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisSubsystem(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().Subsystems);
	
EndFunction

// Checks if the transferred metadata object is a session parameter.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsSessionParameter(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().SessionParameters);
	
EndFunction

// Checks if the transferred metadata object is a common attribute.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsCommonAttribute(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().CommonAttributes);
	
EndFunction

// Checks if the transferred metadata object is a constant.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsConstant(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().Constants);
	
EndFunction

// Checks if the transferred metadata object is a catalog.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsCatalog(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().Catalogs);
	
EndFunction

// Checks if the transferred metadata object is a document.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsDocument(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().Documents);
	
EndFunction

// Checks if the transferred metadata object is a metadata enumeration.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsEnum(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().Enums);
	
EndFunction

// Checks if the transferred metadata object is a business process.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsBusinessProcess(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().BusinessProcesses);
	
EndFunction

// Checks if the transferred metadata object is a task.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsTask(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().Tasks);
	
EndFunction

// Checks if the transferred metadata object is an accounts plan.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsChartOfAccounts(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().ChartsOfAccounts);
	
EndFunction

// Checks if the transferred metadata object is an exchange plan.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsExchangePlan(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().ExchangePlans);
	
EndFunction

// Checks if the transferred metadata object is a calculations kinds plan.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsChartOfCalculationTypes(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().ChartsOfCalculationTypes);
	
EndFunction

// Checks if the transferred metadata object is a calculations kinds plan.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsChartOfCharacteristicTypes(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().ChartsOfCharacteristicTypes);
	
EndFunction

// Checks if the transferred metadata object is a reference.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsReferenceData(Val MetadataObject) Export
	
	Return ThisIsCatalog(MetadataObject)
		Or ThisIsDocument(MetadataObject) 
		Or ThisIsBusinessProcess(MetadataObject) 
		Or ThisIsTask(MetadataObject) 
		Or ThisIsChartOfAccounts(MetadataObject) 
		Or ThisIsExchangePlan(MetadataObject) 
		Or ThisIsChartOfCharacteristicTypes(MetadataObject) 
		Or ThisIsChartOfCalculationTypes(MetadataObject)
		OR IsEnum(MetadataObject);
		
EndFunction

// Checks if the transferred metadata object is a reference one with a support of the predefined items.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsReferenceDataSupportPredefinedItems(Val MetadataObject) Export
	
	Return ThisIsCatalog(MetadataObject)
		OR ThisIsChartOfAccounts(MetadataObject)
		OR ThisIsChartOfCharacteristicTypes(MetadataObject)
		OR ThisIsChartOfCalculationTypes(MetadataObject);
	
EndFunction

// Checks if the transferred metadata object is an information register.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsInformationRegister(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().InformationRegisters);
	
EndFunction

// Checks if the transferred metadata object is an accumulation register.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsAccumulationRegister(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().AccumulationRegisters);
	
EndFunction

// Checks if the transferred metadata object is an accounting register.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsAccountingRegister(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().AccountingRegisters);
	
EndFunction

// Checks if the transferred metadata object is a calculation register.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsCalculationRegister(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().CalculationRegisters);
	
EndFunction

// Checks if the transferred metadata object is a recalculation.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsRecalculationRecordSet(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().Recalculations);
	
EndFunction

// Checks if the transferred metadata object is a sequence.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsSequenceRecordSet(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().Sequences);
	
EndFunction

// Checks if the transferred metadata object is a records set.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsRecordSet(Val MetadataObject) Export
	
	Return ThisIsInformationRegister(MetadataObject)
		Or ThisIsAccumulationRegister(MetadataObject) 
		Or IsAccountingRegister(MetadataObject) 
		Or ThisIsCalculationRegister(MetadataObject) 
		Or IsSequenceRecordSet(MetadataObject) 
		Or IsRecalculationRecordSet(MetadataObject);
	
EndFunction

// Checks if the transferred metadata object is independent records set.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsIndependentRecordSet(Val MetadataObject) Export
	
	If TypeOf(MetadataObject) = Type("String") Then
		MetadataObject = Metadata.FindByFullName(MetadataObject);
	EndIf;
	
	Return ThisIsInformationRegister(MetadataObject)
		AND MetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent;
	
EndFunction

// Checks if the transferred metadata object is set of records with totals support.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsRecordSetSupportsTotals(Val MetadataObject) Export
	
	If ThisIsInformationRegister(MetadataObject) Then
		
		If TypeOf(MetadataObject) = Type("String") Then
			MetadataObject = Metadata.FindByFullName(MetadataObject);
		EndIf;
		
		Return (MetadataObject.AllowTotalsSliceFirst OR MetadataObject.AllowTotalsSliceLast);
		
	ElsIf ThisIsAccumulationRegister(MetadataObject) Then
		
		Return True;
		
	ElsIf IsAccountingRegister(MetadataObject) Then
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

// Checks if the transferred metadata object is a documents log.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function IsDocumentJournal(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().DocumentJournals);
	
EndFunction

// Checks if the transferred metadata object is a statutory job.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsScheduledJob(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().ScheduledJobs);
	
EndFunction

// Checks if the transferred metadata object is an external data source.
//
// Parameters:
//  MetadataObject - checked metadata object.
//
// Return value: Boolean.
//
Function ThisIsExternalDataSource(Val MetadataObject) Export
	
	Return IsClassMetadataObject(MetadataObject, CommonUseSTLReUse.MetadataClassesInConfigurationModel().ExternalDataSources);
	
EndFunction

// Returns: whether this is a primitive type or not.
//
// Parameters:
//  CheckedType - Type - checked type.
//
// Returns:
//  True - if type is primitive.
//
Function IsPrimitiveType(Val CheckedType) Export
	
	Return CommonUseSTLReUse.PrimitiveTypeDescription().ContainsType(CheckedType);
	
EndFunction

// Returns: whether this is a reference type or not.
//
// Parameters:
//  CheckedType - Type - checked type.
//
// Returns:
//  True - if type is primitive.
//
Function IsReferenceType(Val CheckedType) Export
	
	Return CommonUseSTLReUse.ReferenceTypeDescription().ContainsType(CheckedType);
	
EndFunction

// Checks if the type contains a reference type set.
//
// Parameters:
//  TypeDescription - TypeDescription.
//
// Return value: Boolean.
//
Function IsRefsTypesSet(Val TypeDescription) Export
	
	If TypeDescription.Types().Count() < 2 Then
		Return False;
	EndIf;
	
	TypeDescriptionSerialization = XDTOSerializer.WriteXDTO(TypeDescription);
	
	If TypeDescriptionSerialization.TypeSet.Count() > 0 Then
		
		ContainsRefsSets = False;
		
		For Each TypesSet IN TypeDescriptionSerialization.TypeSet Do
			
			If TypesSet.NamespaceURI = "http://v8.1c.ru/8.1/data/enterprise/current-config" Then
				
				If TypesSet.LocalName = "AnyRef"
						OR TypesSet.LocalName = "CatalogRef"
						OR TypesSet.LocalName = "DocumentRef"
						OR TypesSet.LocalName = "BusinessProcessRef"
						OR TypesSet.LocalName = "TaskRef"
						OR TypesSet.LocalName = "ChartOfAccountsRef"
						OR TypesSet.LocalName = "ExchangePlanRef"
						OR TypesSet.LocalName = "ChartOfCharacteristicTypesRef"
						OR TypesSet.LocalName = "ChartOfCalculationTypesRef" Then
					
					ContainsRefsSets = True;
					Break;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		Return ContainsRefsSets;
		
	Else
		Return False;
	EndIf;
	
EndFunction

// Returns metadata object by the reference type
//
// Parameters:
//  ReferenceType - Type,
//
// Return value: MetadataObject.
//
Function MetadataObjectByTypeRefs(Val ReferenceType) Export
	
	BusinessProcess = CommonUseSTLReUse.BusinessProcessesRoutePointsRefs().Get(ReferenceType);
	If BusinessProcess = Undefined Then
		Refs = New(ReferenceType);
		MetadataRefs = Refs.Metadata();
	Else
		MetadataRefs = Metadata.BusinessProcesses[BusinessProcess];
	EndIf;
	
	Return MetadataRefs;
	
EndFunction

// Checks if metadata object is included into a content of a separator in a mode which includes data separation.
//
// Parameters:
//  MetadataObject - checked
//  metadata object, SeparatorName - String - name of the common attribute - separator.
//
// Return value: Boolean.
//
Function IsSeparatedMetadataObject(Val MetadataObject, Val DelimiterName) Export
	
	Properties = ConfigurationModelObjectProperties(CommonUseSTLReUse.ConfigurationDataModelDescription(), MetadataObject);
	Return Properties.DataSeparation.Property(DelimiterName);
	
EndFunction

// Returns a list of objects that have references in the source metadata object.
// Sets of references and references in the value storage are not taken into account.
//
// Parameters:
//  MetadataObject.
//
// Return value: Array(Row) - full names array of metadata objects.
//
Function MetadataObjectDependence(Val MetadataObject) Export
	
	Properties = ConfigurationModelObjectProperties(CommonUseSTLReUse.ConfigurationDataModelDescription(), MetadataObject);
	Return Properties.Dependencies;
	
EndFunction

// Checks if the metadata objects are available by the current values of the functional options.
//
// Parameters:
//  MetadataObject.
//
// Return value: Boolean.
//
Function MetadataObjectAvailableByFunctionalOptions(Val MetadataObject) Export
	
	Properties = ConfigurationModelObjectProperties(CommonUseSTLReUse.ConfigurationDataModelDescription(), MetadataObject);
	
	If Properties.FunctionalOptions.Count() = 0 Then
		Return True;
	Else
		Result = False;
		For Each FunctionalOption IN Properties.FunctionalOptions Do
			If GetFunctionalOption(FunctionalOption) Then
				Result = True;
			EndIf;
		EndDo;
		Return Result;
	EndIf;
	
EndFunction

// Returns the presentation of metadata object.
//
// Parameters:
//  MetadataObject.
//
// Return value: String - metadata object presentation.
//
Function MetadataObjectPresentation(Val MetadataObject) Export
	
	Properties = ConfigurationModelObjectProperties(CommonUseSTLReUse.ConfigurationDataModelDescription(), MetadataObject);
	Return Properties.Presentation;
	
EndFunction

// Returns a list (with classification) of rights allowed for a metadata object.
//
// Parameters:
//  MetadataObject - MetadataObject, MetadataObjectConfiguration.
//
// Return value: ValuesTable:
//                         * Name - String, name of the right
//                                    kind which can
//                         be used for the AccessRight function(),  * Interactive - Boolean, a flag that shows that the right restricts the option to execute interactive operations, * Reading - Boolean, a check box that the
//                                    right provides or implies the possibility
//                         of reading the data of set metadata object, * Change - Boolean, a check box that the
//                                    right provides or implies the possibility
//                         of changing the data of set metadata object, * InfobaseAdministration - Boolean, a check
//                                    box that the right provides
//                                    or implies the possibility
//                         of administration (global for infobase), * DataFieldAdministration - Boolean, a check box
//                                    that the right provides or implies
//                                    the possibility of administration (global for the current data field).
//
Function ValidRightsForMetadataObject(Val MetadataObject) Export
	
	RightsKind = New ValueTable();
	RightsKind.Columns.Add("Name", New TypeDescription("String"));
	RightsKind.Columns.Add("Interactive", New TypeDescription("Boolean"));
	RightsKind.Columns.Add("Read", New TypeDescription("Boolean"));
	RightsKind.Columns.Add("Update", New TypeDescription("Boolean"));
	RightsKind.Columns.Add("InfobaseAdministration", New TypeDescription("Boolean"));
	RightsKind.Columns.Add("DataAreaAdministration", New TypeDescription("Boolean"));
	
	If IsObjectMetadataConfiguration(MetadataObject) Then
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Administration";
		RightKind.InfobaseAdministration = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "DataAdministration";
		RightKind.DataAreaAdministration = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "UpdateDataBaseConfiguration";
		RightKind.InfobaseAdministration = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "ExclusiveMode";
		RightKind.DataAreaAdministration = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "ActiveUsers";
		RightKind.DataAreaAdministration = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "EventLogMonitor";
		RightKind.DataAreaAdministration = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "ThinClient";
		RightKind.Interactive = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "WebClient";
		RightKind.Interactive = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "ThickClient";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "ExternalConnection";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Automation";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "AllFunctionsMode";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "SaveUserData";
		RightKind.Interactive = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "InteractiveOpenExtDataProcessors";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "InteractiveOpenExtReports";
		RightKind.InfobaseAdministration = True;
		RightKind.Interactive = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Output";
		RightKind.Interactive = True;
		
	ElsIf IsSessionParameter(MetadataObject) Then
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Get";
		RightKind.Read = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Setting";
		RightKind.Update = True;
		
	ElsIf IsCommonAttribute(MetadataObject) Then
		
		RightKind = RightsKind.Add();
		RightKind = "view";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Edit";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
	ElsIf ThisIsConstant(MetadataObject) Then
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Read";
		RightKind.Read = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Update";
		RightKind.Update = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "view";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Edit";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
	ElsIf ThisIsReferenceData(MetadataObject) Then
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Read";
		RightKind.Read = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Insert";
		RightKind.Update = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Update";
		RightKind.Update = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Delete";
		RightKind.Update = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "view";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "InteractiveInsert";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Edit";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "InteractiveDelete";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "InteractiveDeleteMark";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "InteractiveDeleteMarkDeletion";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "InteractiveDeleteMarked";
		RightKind.Interactive = True;
		RightKind.Update = True;
		
		If ThisIsDocument(MetadataObject) Then
			
			RightKind = RightsKind.Add();
			RightKind.Name = "Posting";
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "UndoPosting";
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractivePosting";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractiveNonOperationalPosting";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractivePostingCancelation";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractivePostedChange";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "InputByString";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
		If ThisIsBusinessProcess(MetadataObject) Then
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractiveActivation";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "Start";
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractiveStart";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
		If ThisIsTask(MetadataObject) Then
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractiveActivation";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "Execution";
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractiveExecution";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
		If IsReferenceDataSupportPredefinedItems(MetadataObject) Then
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractiveDeleteOfPredefinedData";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractivePredefinedDataRemovalMark";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractivePredefinedDataMarkRemoval";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "InteractiveMarkedPredefinedDataRemoval";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
	ElsIf ThisIsRecordSet(MetadataObject) Then
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Read";
		RightKind.Read = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Update";
		RightKind.Update = True;
		
		If Not IsSequenceRecordSet(MetadataObject) AND Not IsRecalculationRecordSet(MetadataObject) Then
			
			RightKind = RightsKind.Add();
			RightKind.Name = "view";
			RightKind.Interactive = True;
			RightKind.Read = True;
			
			RightKind = RightsKind.Add();
			RightKind.Name = "Edit";
			RightKind.Interactive = True;
			RightKind.Update = True;
			
		EndIf;
		
		If ThisIsRecordSetSupportsTotals(MetadataObject) Then
			
			RightKind = RightsKind.Add();
			RightKind.Name = "TotalsControl";
			RightKind.DataAreaAdministration = True;
			
		EndIf;
		
	ElsIf IsDocumentJournal(MetadataObject) Then
		
		RightKind = RightsKind.Add();
		RightKind.Name = "Read";
		RightKind.Read = True;
		
		RightKind = RightsKind.Add();
		RightKind.Name = "view";
		RightKind.Interactive = True;
		RightKind.Read = True;
		
	EndIf;
	
	Return RightsKind;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Checks if the configuration contains SSL.
//
// Return value: Boolean.
//
Function ContainsSSLConfiguration()
	
	Return (Metadata.Subsystems.Find("StandardSubsystems") <> Undefined);
	
EndFunction

// Checks if the current configuration supports applicationmatic SSL events.
//
// Return value: Boolean.
//
Function SupportProgrammaticEvents()
	
	If Not ContainsSSLConfiguration() Then
		Return False;
	EndIf;
	
	Try
		
		SetSafeMode(True);
		Parameters = Eval("StandardSubsystemsreuse.ProgramEventsParameters()");
		Return True;
		
	Except
		Return False;
	EndTry;
	
EndFunction

// Returns the handlers of the applicationmatic SSL events.
//
// Parameters:
//  Event - String - event name.
//
Function GetProgrammaticSSLEventHandlers(Val Event) Export
	
	If SupportProgrammaticEvents() Then
		
		SetSafeMode(True);
		Return Eval("CommonUse.ServiceEventProcessor(Event)");
		
	Else
		Return New Array();
	EndIf;
	
EndFunction

Function ConfigurationModelObjectProperties(Val Model, Val MetadataObject) Export
	
	If TypeOf(MetadataObject) = Type("MetadataObject") Then
		Name = MetadataObject.Name;
		DescriptionFull = MetadataObject.FullName();
	Else
		DescriptionFull = MetadataObject;
		Name = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DescriptionFull, ".").Get(1);
	EndIf;
	
	For Each ModelClass IN Model Do
		
		ObjectDescription = ModelClass.Value.Get(Name);
		
		If ObjectDescription <> Undefined Then
			
			If DescriptionFull = ObjectDescription.DescriptionFull Then
				
				Return ObjectDescription;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndFunction

Function IsClassMetadataObject(Val MetadataObject, Val Class)
	
	If TypeOf(MetadataObject) = Type("MetadataObject") Then
		Name = MetadataObject.Name;
		DescriptionFull = MetadataObject.FullName();
	Else
		DescriptionFull = MetadataObject;
		Name = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DescriptionFull, ".").Get(1);
	EndIf;
	
	ModelGroup = CommonUseSTLReUse.ConfigurationDataModelDescription().Get(Class);
	
	ObjectDescription = ModelGroup.Get(Name);
	
	If ObjectDescription <> Undefined Then
		
		Return DescriptionFull = ObjectDescription.DescriptionFull;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

#EndRegion