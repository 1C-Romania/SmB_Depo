////////////////////////////////////////////////////////////////////////////////
// Subsystem "Basic functionality in service model".
// Server procedures and functions of common use:
// - Support of operation in service model
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnEnableSeparationByDataAreas"].Add(
		"SaaSSTL");
	
	ServerHandlers["StandardSubsystems.SaaS\WhenCompletingTablesOfParametersOfIB"].Add(
		"SaaSSTL");
	
	ServerHandlers["ServiceTechnology.BasicFunctionality\WhenGeneratingConfigurationManifest"].Add(
		"SaaSSTL");
	
EndProcedure

// Adds to the list of
// procedures (IB data update handlers) for all supported versions of the library or configuration.
// Appears before the start of IB data update to build up the update plan.
//
// Parameters:
//  Handlers - ValueTable - See description
// of the fields in the procedure InfobaseUpdate.UpdateHandlersNewTable
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.Version              = "1.0.0.0";
//  Handler.Procedure           = "IBUpdate.SwitchToVersion_1_0_0_0";
//  Handler.ExclusiveMode    = False;
//  Handler.Optional        = True;
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.Procedure = "SaaSSTL.CreateUndividedPredefinedItems";
		Handler.Priority = 99;
		Handler.SharedData = True;
		Handler.ExclusiveMode = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Called up at enabling data classification into data fields.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	CreateUndividedPredefinedItems();
	
EndProcedure

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetIBParameterTable()
//
Procedure WhenCompletingTablesOfParametersOfIB(Val ParameterTable) Export
	
	If CommonUseClientServer.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaSOperations = CommonUseClientServer.CommonModule("SaaSOperations");
		ModuleSaaSOperations.AddConstantToInfobaseParameterTable(ParameterTable, "ControlApplicationExternalAddress");
	EndIf;
	
EndProcedure

// Handler of creation/update
// of predefined items of undivided metadata objects.
//
Procedure CreateUndividedPredefinedItems() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		
		Raise NStr("en = 'Operation can not be executed only in the session in which values of the separators are set'");
		
	EndIf;
	
	If CommonUseSTLReUse.AvailableMechanismsCompatibilityMode8_3_5() Then
		
		InitializePredefinedData();
		
	Else
		
		MainSplitter        = SaaSOperations.MainDataSeparator();
		SupportSplitter = SaaSOperations.SupportDataSplitter();
		
		MetadataCollections = New Array;
		MetadataCollections.Add(Metadata.Catalogs);
		MetadataCollections.Add(Metadata.ChartsOfCharacteristicTypes);
		MetadataCollections.Add(Metadata.ChartsOfAccounts);
		MetadataCollections.Add(Metadata.ChartsOfCalculationTypes);
		
		For Each Collection IN MetadataCollections Do
			For Each MetadataObject IN Collection Do
				DescriptionFull = MetadataObject.FullName();
				If Not CommonUseReUse.IsSeparatedMetadataObject(DescriptionFull, MainSplitter)
				   AND Not CommonUseReUse.IsSeparatedMetadataObject(DescriptionFull, SupportSplitter) Then
					
					ObjectManager = CommonUse.ObjectManagerByFullName(DescriptionFull);
					ObjectManager.Select().Next();
				EndIf;
			EndDo;
		EndDo;
		
	EndIf;
	
EndProcedure

// Called up at generating the configuration manifest.
//
// Parameters:
//  AdvancedInformation - Array, inside handler procedure it is
//    required to add to this array objects of
//    the type ObjectXDTO with TypeXDTO derived from {http:www.1c.ru/1CFresh/Application/Manifest/a.b.c.d}ExtendedInfoItem.
//
Procedure WhenGeneratingConfigurationManifest(AdvancedInformation) Export
	
	If TransactionActive() Then
		Raise NStr("en = 'Operation can not be executed when an external transaction is active!'");
	EndIf;
	
	CallInUndividedIB = Not CommonUseReUse.DataSeparationEnabled();
	
	BeginTransaction();
	
	Try
		
		PermissionsDescription = XDTOFactory.Create(
			XDTOFactory.Type("http://www.1c.ru/1cFresh/Application/Permissions/Manifes/1.0.0.1", "RequiredPermissions")
		);
		
		ExternalComponentsDescription = XDTOFactory.Create(
			XDTOFactory.Type("http://www.1c.ru/1cFresh/Application/Permissions/Manifes/1.0.0.1", "Addins")
		);
		
		ExternalComponentTemplates = New Map();
		
		If CallInUndividedIB Then
			
			Constants.UseSeparationByDataAreas.Set(True);
			RefreshReusableValues();
			
		EndIf;
		
		Constants.SecurityProfilesAreUsed.Set(True);
		Constants.AutomaticallyConfigurePermissionsInSecurityProfiles.Set(True);
		
		QueryIDs = WorkInSafeMode.ConfigurationPermissionsUpdateQueries();
		
		ApplicationManager = WorkInSafeModeServiceSaaS.PermissionsApplicationManager(QueryIDs);
		Delta = ApplicationManager.DeltaNotIncludingOwners();
		
		ExternalComponentTemplates = New Array();
		
		For Each DeltaItem IN Delta.Adding Do
			
			For Each KeyAndValue IN DeltaItem.permissions Do
				
				Resolution = CommonUse.ObjectXDTOFromXMLRow(KeyAndValue.Value);
				PermissionsDescription.Permission.Add(Resolution);
				
				If Resolution.Type() = XDTOFactory.Type("http://www.1c.ru/1cFresh/Application/Permissions/1.0.0.1", "AttachAddin") Then
					ExternalComponentTemplates.Add(Resolution.TemplateName);
				EndIf;
				
			EndDo;
			
		EndDo;
		
		For Each TemplateName IN ExternalComponentTemplates Do
			
			ExternalComponentDescription = XDTOFactory.Create(XDTOFactory.Type("http://www.1c.ru/1cFresh/Application/Permissions/Manifes/1.0.0.1", "AddinBundle"));
			ExternalComponentDescription.TemplateName = TemplateName;
			
			FileDescriptionFulls = WorkInSafeMode.ExternalComponentsKitFilesControlSums(TemplateName);
			
			For Each KeyAndValue IN FileDescriptionFulls Do
				
				FileDescription = XDTOFactory.Create(XDTOFactory.Type("http://www.1c.ru/1cFresh/Application/Permissions/Manifes/1.0.0.1", "AddinFile"));
				FileDescription.FileName = KeyAndValue.Key;
				FileDescription.Hash = KeyAndValue.Value;
				
				ExternalComponentDescription.Files.Add(FileDescription);
				
			EndDo;
			
			ExternalComponentsDescription.Bundles.Add(ExternalComponentDescription);
			
		EndDo;
		
		AdvancedInformation.Add(PermissionsDescription);
		AdvancedInformation.Add(ExternalComponentsDescription);
		
	Except
		
		RollbackTransaction();
		If CallInUndividedIB Then
			RefreshReusableValues();
		EndIf;
		
		Raise;
		
	EndTry;
	
	RollbackTransaction();
	If CallInUndividedIB Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

#EndRegion