////////////////////////////////////////////////////////////////////////////////
// Work with additional reports and processors manifest
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Generates an additional report or data processor manifest
//
// Parameters:
//  DataProcessorObject - object, property values of which
//    will be used as values of the additional
//    report properties
//    or
//  data processor (presumably CatalogObject.AdditionalReportsAndDataProcessors or CatalogObject.SuppliedAdditionalReportsAndDataProcessors, ObjectVersion - object, property values of which
//    will be used as values of the additional report
//    properties or
//    data
//  processor (presumably CatalogObject.AdditionalReportsAndDataProcessors or CatalogObject.SuppliedAdditionalReportsAndDataProcessors, ReportVariant - ValueTable, columns:
//    VariantKey - String, additional report
//    variant key, Presentation - String, report additional variant
//    presentation, Function - ValueTable, columns:
//      SectionOrGroup - String that can map
//        catalog
//      item MetadataObjectIdentificators, Important - Boolean,
//      SeeAlso - Boolean.
//
// Returns:
//  XDTOObject {http://www.1c.ru/1CFresh/ApplicationExtensions/Manifest/a.b.c.d}ExtensionManifest -
//    additional report or data processor manifest
//
// Note:
//  IN addition to the BSP code, this function
//   can be
//   called from external data processor AdditionalReportsAndDataProcessorsToPublicationSaaSPreparation.epf that is supplied with manager service. On changing structure parameters
//   of this function it is required to actualize them in this external data processor.
//
Function GenerateManifest(Val DataProcessorObject, Val VersionObject, Val ReportVariants = Undefined, Val CommandsSchedules = Undefined, Val PermissionsDataProcessors = Undefined) Export
	
	Try
		PermissionsCompatibilityMode = DataProcessorObject.PermissionsCompatibilityMode;
	Except
		PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3;
	EndTry;
	
	If PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3 Then
		Package = AdditionalReportsAndDataProcessorsSaaSManifestInterface.Package("1.0.0.1");
	Else
		Package = AdditionalReportsAndDataProcessorsSaaSManifestInterface.Package();
	EndIf;
	
	Manifest = XDTOFactory.Create(
		AdditionalReportsAndDataProcessorsSaaSManifestInterface.TypeManifest(Package));
	
	Manifest.Name = DataProcessorObject.Description;
	Manifest.ObjectName = VersionObject.ObjectName;
	Manifest.Version = VersionObject.Version;
	
	If PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3 Then
		Manifest.SafeMode = VersionObject.SafeMode;
	EndIf;
	
	Manifest.Description = VersionObject.Information;
	Manifest.FileName = VersionObject.FileName;
	Manifest.UseReportVariantsStorage = VersionObject.UsesVariantsStorage;
	
	XDTOKind = Undefined;
	DictionaryConversionOfDataprocessors =
		AdditionalReportsAndDataProcessorsSaaSManifestInterface.DictionaryAdditionalReportAndDataProcessorTypes();
	For Each DictionaryFragment IN DictionaryConversionOfDataprocessors Do
		If DictionaryFragment.Value = VersionObject.Type Then
			XDTOKind = DictionaryFragment.Key;
		EndIf;
	EndDo;
	If ValueIsFilled(XDTOKind) Then
		Manifest.Category = XDTOKind;
	Else
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='%1 additional reports and processings type is not supported in the service model!';ru='Вид дополнительных отчетов и обработок %1 не поддерживается в модели сервиса!'"),
			VersionObject.Type);
	EndIf;
	
	If VersionObject.Commands.Count() > 0 Then
		
		If DataProcessorObject.Type = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalInformationProcessor Or
				DataProcessorObject.Type = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
			
			// Section function data processor
			
			SelectedSections = VersionObject.Sections.Unload();
			
			If DataProcessorObject.Type = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalInformationProcessor Then
				PossiblePartitions = AdditionalReportsAndDataProcessors.AdditionalDataProcessorSections();
			Else
				PossiblePartitions = AdditionalReportsAndDataProcessors.AdditionalReportsSections();
			EndIf;
			
			Desktop = AdditionalReportsAndDataProcessorsClientServer.DesktopID();
			
			XDTOPrescription = XDTOFactory.Create(
				AdditionalReportsAndDataProcessorsSaaSManifestInterface.SectionPrescriptionType(Package));
			
			For Each Section IN PossiblePartitions Do
				
				If Section = Desktop Then
					SectionName = Desktop;
					MetadataObjectID = Catalogs.MetadataObjectIDs.EmptyRef();
				Else
					SectionName = Section.FullName();
					MetadataObjectID = CommonUse.MetadataObjectID(Section);
				EndIf;
				MetadataObjectPresentation = AdditionalReportsAndDataProcessors.PresentationOfSection(Section);
				
				DestinationObjectXDTO = XDTOFactory.Create(
					AdditionalReportsAndDataProcessorsSaaSManifestInterface.TypeDestinationObject(Package));
				DestinationObjectXDTO.ObjectName = SectionName;
				DestinationObjectXDTO.ObjectType = "SubSystem";
				DestinationObjectXDTO.Representation = MetadataObjectPresentation;
				DestinationObjectXDTO.Enabled = (
					SelectedSections.Find(
						MetadataObjectID, "Section"
					) <> Undefined);
				
				XDTOPrescription.Objects.Append(DestinationObjectXDTO);
				
			EndDo;
			
		Else
			
			// Data processor of metadata objects destination
			
			SelectedDestinationObjects = VersionObject.Purpose.Unload();
			
			PossibleDestinationObjects = New Array();
			If DataProcessorObject.Type = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling Then
				CommonCommand = Metadata.CommonCommands.ObjectFilling;
			ElsIf DataProcessorObject.Type = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
				CommonCommand = Metadata.CommonCommands.ObjectReports;
			ElsIf DataProcessorObject.Type = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
				CommonCommand = Metadata.CommonCommands.ObjectAdditionalPrintForms;
			ElsIf DataProcessorObject.Type = Enums.AdditionalReportsAndDataProcessorsKinds.CreatingLinkedObjects Then
				CommonCommand = Metadata.CommonCommands.CreatingLinkedObjects;
			EndIf;
			For Each CommandParameterType IN CommonCommand.CommandParameterType.Types() Do
				PossibleDestinationObjects.Add(Metadata.FindByType(CommandParameterType));
			EndDo;
			
			XDTOPrescription = XDTOFactory.Create(
				AdditionalReportsAndDataProcessorsSaaSManifestInterface.TypePurposeCatalogsAndDocuments(Package));
			
			For Each ObjectDestination IN PossibleDestinationObjects Do
				
				MetadataObjectID = CommonUse.MetadataObjectID(ObjectDestination);
				
				DestinationObjectXDTO = XDTOFactory.Create(
					AdditionalReportsAndDataProcessorsSaaSManifestInterface.TypeDestinationObject(Package));
				DestinationObjectXDTO.ObjectName = ObjectDestination.FullName();
				If CommonUse.ThisIsCatalog(ObjectDestination) Then
					DestinationObjectXDTO.ObjectType = "Catalog";
				ElsIf CommonUse.ThisIsDocument(ObjectDestination) Then
					DestinationObjectXDTO.ObjectType = "Document";
				ElsIf CommonUse.ThisIsBusinessProcess(ObjectDestination) Then
					DestinationObjectXDTO.ObjectType = "BusinessProcess";
				ElsIf CommonUse.ThisIsTask(ObjectDestination) Then
					DestinationObjectXDTO.ObjectType = "Task";
				EndIf;
				DestinationObjectXDTO.Representation = ObjectDestination.Presentation();
				DestinationObjectXDTO.Enabled = (
					SelectedDestinationObjects.Find(
						MetadataObjectID, "ObjectDestination"
					) <> Undefined);
				
				XDTOPrescription.Objects.Append(DestinationObjectXDTO);
				
			EndDo;
			
			XDTOPrescription.UseInListsForms = VersionObject.UseForListForm;
			XDTOPrescription.UseInObjectsForms = VersionObject.UseForObjectForm;
			
		EndIf;
		
		Manifest.Assignment = XDTOPrescription;
		
		For Each CommandDetails IN VersionObject.Commands Do
			
			XDTOCommand = XDTOFactory.Create(
				AdditionalReportsAndDataProcessorsSaaSManifestInterface.TypeCommand(Package));
			XDTOCommand.Id = CommandDetails.ID;
			XDTOCommand.Representation = CommandDetails.Presentation;
			
			XDTOStartType = Undefined;
			DictionaryConversionWaysCall =
				AdditionalReportsAndDataProcessorsSaaSManifestInterface.DictionaryWaysCallAdditionalReportsAndDataprocessors();
			For Each DictionaryFragment IN DictionaryConversionWaysCall Do
				If DictionaryFragment.Value = CommandDetails.StartVariant Then
					XDTOStartType = DictionaryFragment.Key;
				EndIf;
			EndDo;
			If ValueIsFilled(XDTOStartType) Then
				XDTOCommand.StartupType = XDTOStartType;
			Else
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='The %1 launch method of the additional reports and data processors is not supported in the service model!';ru='Способ запуска дополнительных отчетов и обработок %1 не поддерживается в модели сервиса!'"),
					CommandDetails.StartVariant);
			EndIf;
			
			XDTOCommand.ShowNotification = CommandDetails.ShowAlert;
			XDTOCommand.Modifier = CommandDetails.Modifier;
			
			If ValueIsFilled(CommandsSchedules) Then
				
				CommandSchedule = Undefined;
				If CommandsSchedules.Property(CommandDetails.ID, CommandSchedule) Then
					
					XDTOCommand.DefaultSettings = XDTOFactory.Create(
						AdditionalReportsAndDataProcessorsSaaSManifestInterface.TypeSettingsCommands(Package));
					
					XDTOCommand.DefaultSettings.Schedule = XDTOSerializer.WriteXDTO(CommandSchedule);
					
				EndIf;
				
			EndIf;
			
			Manifest.Commands.Append(XDTOCommand);
			
		EndDo;
		
	EndIf;
	
	If ValueIsFilled(ReportVariants) Then
		
		For Each ReportVariant IN ReportVariants Do
			
			XDTOVariety = XDTOFactory.Create(
				AdditionalReportsAndDataProcessorsSaaSManifestInterface.TypeVariantOfReport(Package));
			XDTOVariety.VariantKey = ReportVariant.VariantKey;
			XDTOVariety.Representation = ReportVariant.Presentation;
			
			If ReportVariant.Purpose <> Undefined Then
				
				For Each ReportOptionPurpose IN ReportVariant.Purpose Do
					
					XDTOPrescription = XDTOFactory.Create(
						AdditionalReportsAndDataProcessorsSaaSManifestInterface.TypeReportOptionPurpose(Package));
					
					XDTOPrescription.ObjectName = ReportOptionPurpose.FullName;
					XDTOPrescription.Representation = ReportOptionPurpose.Presentation;
					XDTOPrescription.Parent = ReportOptionPurpose.ParentFullName;
					XDTOPrescription.Enabled = ReportOptionPurpose.Use;
					
					If ReportOptionPurpose.Important Then
						XDTOPrescription.Importance = "High";
					ElsIf ReportOptionPurpose.SeeAlso Then
						XDTOPrescription.Importance = "Low";
					Else
						XDTOPrescription.Importance = "Ordinary";
					EndIf;
					
					XDTOVariety.Assignments.Append(XDTOPrescription);
					
				EndDo;
				
			EndIf;
			
			Manifest.ReportsVariants.Append(XDTOVariety);
			
		EndDo;
		
	EndIf;
	
	If PermissionsDataProcessors = Undefined Then
		
		PermissionsDataProcessors = DataProcessorObject.permissions;
		
	EndIf;
	
	For Each Resolution IN PermissionsDataProcessors Do
		
		If TypeOf(Resolution) = Type("XDTODataObject") Then
			
			Manifest.Permissions.Append(Resolution);
			
		Else
			
			If PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3 Then
				
				XDTODefinition = XDTOFactory.Create(
					XDTOFactory.Type(
						AdditionalReportsAndDataProcessorsInSafeModeInterface.Package(Package),
						Resolution.TypePermissions));
				
			Else
				
				XDTODefinition = XDTOFactory.Create(
					XDTOFactory.Type(
						"http://www.1c.ru/1cFresh/Application/Permissions/1.0.0.1",
						Resolution.TypePermissions));
				
			EndIf;
			
			Parameters = Resolution.Parameters.Get();
			If Parameters <> Undefined Then
				
				For Each Parameter IN Parameters Do
					
					XDTODefinition[Parameter.Key] = Parameter.Value;
					
				EndDo;
				
			EndIf;
			
			Manifest.Permissions.Append(XDTODefinition);
			
		EndIf;
		
	EndDo;
	
	Return Manifest;
	
EndFunction

// Fills in the passed objects by data
//  read from the additional report or data processors manifest.
//
// Parameters:
//  Manifest - XDTOObject {http://www.1c.ru/1CFresh/ApplicationExtensions/Manifest/a.b.c.d}ExtensionManifest - additional
//    report or data processor
//  manifest, DataProcessorObject - object, the properties values of
//    which will be set as the additional report or
//    data processors
//    properties
//  values from the manifest (presumably CatalogObject.AdditionalReportsAndDataProcessors or CatalogObject.SuppliedAdditionalReportsAndDataProcessors, VersionObject - object, the properties values of
//    which will be set as the additional report or data
//    processors properties
//    values
//  from the manifest (presumably CatalogObject.AdditionalReportsAndDataProcessors or CatalogObject.SuppliedAdditionalReportsAndDataProcessors, ReportVariants - ValueTable, columns:
//    VariantKey - String, additional report
//    variant key, Presentation - String, report additional variant
//    presentation, Function - ValueTable, columns:
//      SectionOrGroup - String that can map
//        catalog
//      item MetadataObjectIdentificators, Important - Boolean,
//      SeeAlso - Boolean.
//
Procedure ReadManifest(Val Manifest, DataProcessorObject, VersionObject, ReportVariants) Export
	
	If Manifest.Type().NamespaceURI = AdditionalReportsAndDataProcessorsSaaSManifestInterface.Package("1.0.0.1") Then
		DataProcessorObject.PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3;
	ElsIf Manifest.Type().NamespaceURI = AdditionalReportsAndDataProcessorsSaaSManifestInterface.Package("1.0.0.2") Then
		DataProcessorObject.PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_2_2;
	EndIf;
	
	DataProcessorObject.Description = Manifest.Name;
	VersionObject.ObjectName = Manifest.ObjectName;
	VersionObject.Version = Manifest.Version;
	If DataProcessorObject.PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3 Then
		VersionObject.SafeMode = Manifest.SafeMode;
	EndIf;
	VersionObject.Information = Manifest.Description;
	VersionObject.FileName = Manifest.FileName;
	VersionObject.UsesVariantsStorage = Manifest.UseReportVariantsStorage;
	
	DictionaryConversionOfDataprocessors = AdditionalReportsAndDataProcessorsSaaSManifestInterface.DictionaryAdditionalReportAndDataProcessorTypes();
	VersionObject.Type = DictionaryConversionOfDataprocessors[Manifest.Category];
	
	VersionObject.Commands.Clear();
	For Each Command IN Manifest.Commands Do
		
		CommandString = VersionObject.Commands.Append();
		CommandString.ID = Command.Id;
		CommandString.Presentation = Command.Representation;
		CommandString.ShowAlert = Command.ShowNotification;
		CommandString.Modifier = Command.Modifier;
		
		DictionaryConversionWaysCall =
			AdditionalReportsAndDataProcessorsSaaSManifestInterface.DictionaryWaysCallAdditionalReportsAndDataprocessors();
		CommandString.StartVariant = DictionaryConversionWaysCall[Command.StartupType];
		
	EndDo;
	
	VersionObject.permissions.Clear();
	For Each Permission IN Manifest.Permissions Do
		
		XDTOType = Permission.Type();
		
		Resolution = VersionObject.permissions.Append();
		Resolution.TypePermissions = XDTOType.Name;
		
		Parameters = New Structure();
		
		For Each XDTOProperty IN XDTOType.Properties Do
			
			Container = Permission.GetXDTO(XDTOProperty.Name);
			
			If Container <> Undefined Then
				Parameters.Insert(XDTOProperty.Name, Container.Value);
			Else
				Parameters.Insert(XDTOProperty.Name);
			EndIf;
			
		EndDo;
		
		Resolution.Parameters = New ValueStorage(Parameters);
		
	EndDo;
	
EndProcedure
