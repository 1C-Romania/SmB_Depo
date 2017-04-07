////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns a match of session parameters and handlers parameters to initialize them.
//
// To specify handlers of session parameters, you should use template:
// Handlers.Insert("<SessionParameterName>|<SessionParameterNamePrefix*>", "Handler");
//
// Note. * character is used in the end of
//             the session parameter name and indicates that one handler will
//             be called for initialization of all session parameters with the name that starts with the word SessionParameterNameStart.
//
Procedure OnAddSessionSettingsSetupHandler(Handlers) Export
	
	// SB
	Handlers.Insert("ThisIsFirstLaunch", 			"SmallBusinessServer.SessionParametersSetting");
	Handlers.Insert("DataExchangeWithSiteEnabled",	"ExchangeWithSite.SetSessionParameters");
	// SB End
	
	// Peripherals
	Handlers.Insert("ClientWorkplace",			"EquipmentManagerServerCall.SetPeripheralsSessionParameters");
	// End Peripherals
	
EndProcedure

// Metadata objects the content of which should not be considered in the application business logic.
//
// Description:
//   The Objects versioning and Properties subsystems are set for the Products and services implementation document.
//   The document can be specified in other metadata objects - documents or registers.
//   Some references are relevant for the business logic (for example, move by registers) and should be shown to a user.
//   Another part of refs - "technology-generated" refs to document from the Object
//     versioning and Properties subsystems data should be hidden from a user while searching for refs to object. 
//     For example, when usage places are analyzed or in the subsystem of key attributes editing prohibition.
//   List of these "technology-generated" objects should be enumerated in this procedure.
//
// IMPORTANT:
//   To prevent empty "dead" refs, it is recommended to consider the
//   procedure of removal of the specified metadata objects.
//   For dimensions of information registers - using the Leading check
//     box selection, then the information register record will be deleted at the same time the ref specified in the dimension is deleted.
//   For other attributes of the specified objects - using subscription to the BeforeRemoval event of
//   all metadata objects types what can be written to attributes of the specified metadata objects.
//     It is required to find "technology-generated" objects in the handler in the
//     attributes of which the ref of the deleted object is specified and select the method of ref clearing: clear attribute value, delete table row or delete the whole object.
//
// Parameters:
//  RefsSearchExceptions - Array - Metadata objects or their attributes content of which should not
//                                    be considered in the application business-logic.
//   * MetadataObject - Metadata object or its attribute.
//   * String - Full name of the metadata object or its attribute.
//
// Examples:
// RefsSearchExceptions.Add(Metadata.InformationRegisters.ObjectsVersions);
// RefsSearchExceptions.Add(Metadata.InformationRegisters.ObjectsVersions.Attributes.VersionAuthor);
// RefsSearchExceptions.Add(InformationRegister.ObjectsVersions);
// 
Procedure OnAddExceptionsSearchLinks(RefsSearchExceptions) Export
	
	// SB
	// "Technology-generated" register CounterpartiesDuplicatesPresence is cleared in the BeforeRemoval handler of the Counterparties catalog object module
	RefsSearchExceptions.Add(Metadata.InformationRegisters.CounterpartyDuplicatesExist);
	// SB End
	
EndProcedure

// Sets a text description of the subject.
//
// Parameters
//  SubjectRef  - AnyRef - an object of a reference type.
//  Presentation	 - String - a text description should be placed here.
Procedure SetSubjectPresentation(SubjectRef, Presentation) Export
	
EndProcedure

// Extends a definition of renaming those
// metadata objects that can not be automatically found by the
// type but refs to which should be saved to the data base (for example: subsystems, rules).
//
// Parameters:
//  Total - ValueTable - table that should be passed
//         as a parameter to the AddRenaming procedure of the CommonUse common module.
//
// Example:
// CommonUse.AddRenaming(Total, "2.2.1.7",
// 	"Role.EDSUse", "Role.DSUsage", "StandardSubsystems");
//
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "SmallBusiness";
	CommonUse.AddRenaming(Total, "1.4.9.2", "Subsystem.Analysis", "Subsystem.AnalysisReports", Library);
	
	// OnlineUserSupport
	OnlineUserSupport.OnAddMetadataObjectsRenaming(Total);
	// End OnlineUserSupport

EndProcedure

// It returns the structure of the parameters
// necessary for the work of client code when launching the configuration, i.e. in the event handlers.
// - BeforeSystemWorkStart,
// - OnStart
//
// Important: when starting you can not use
// cache reset command for reused modules otherwise
// the start can lead to unpredictable errors and excess server calls.
//
// Parameters:
//   Parameters - Structure - (return value) structure of client works parameters on start.
//
// Example of implementation:
//   To set client work parameters, you can use template:
//
//     Parameters.Insert(<ParameterName>, <code of getting parameter value>);
//
//
Procedure ClientWorkParametersOnStart(Parameters) Export
	
	// OnlineUserSupport
	OnlineUserSupport.ClientWorkParametersOnStart(Parameters);
	// End OnlineUserSupport
	
EndProcedure

// It returns the structure of the parameters
// required for the client configuration code working.
//
// Parameters:
//   Parameters - Structure - (return value) structure of client works parameters.
//
// Example of implementation:
//   To set client work parameters, you can use template:
//
//     Parameters.Insert(<ParameterName>, <code of getting parameter value>);
//
Procedure ClientWorkParameters(Parameters) Export
	
	// OnlineUserSupport
	OnlineUserSupport.ClientWorkParameters(Parameters);
	// End OnlineUserSupport
	
EndProcedure

// Returns parameters structure required for work
// of the configuration client code on completing i.e. in the handlers:
// - BeforeExit,
// - OnExit
//
// Parameters:
//   Parameters - Structure - (return value) structure of client works parameters on end.
//
// Example of implementation:
//   To set client work parameters on end, you can use a template:
//
//     Parameters.Insert(<ParameterName>, <code of getting parameter value>);
//
Procedure ClientWorkParametersOnComplete(Parameters) Export
	
EndProcedure

// Allows to set general parameters of subsystems.
//
// Parameters:
//  CommonParameters - Structure - structure with properties:
//      * PersonalSettingsFormName            - String - form name for editing personal settings.
//                                                           Previously defined
//                                                           in CommonUseOverridable.PersonalSettingsFormName.
//      *  MinimumRequiredPlatformVersion    - String - full number of the platform version for application start.
//                                                           ForExample, 8.3.4.365.
//                                                           Previously defined
//                                                           in CommonUseOverridable.GetMinRequiredPlatformVersion.
//      * WorkInParameterProhibited               - Boolean - Initial value is False.
//      * RequestApprovalOnApplicationEnd - Boolean - True by default. If you set False,
//                                                                  then the approval during the application
//                                                                  shutdown will not be requested if you do
//                                                                  not allow it in personal application settings.
//      * DisableCatalogMetadataObjectsIDs - Boolean - disables catalog filling.
//              MetadataObjectsIdentifiers, procedures of export and import catalog items in DIB nodes.
//              For partial embedding of the separate library function in the configuration without registration for support.
//
Procedure OnDefiningGeneralParametersBasicFunctionality(CommonParameters) Export
	
	// SB
	CommonParameters.Insert("MinimallyRequiredPlatformVersion","8.3.5.1280");
	CommonParameters.Insert("FormNamePersonalSettings", "CommonForm.PersonalSettings");
	// SB End
	
EndProcedure

// Handler of the Before metadata objects identifiers import in the subordinate DIB node event.
// Fills in the settings of locating the
// data exchange message or irregular import of the metadata objects identifiers from the main node.
//
// Parameters:
//  StandardProcessing - Boolean, True initial value if you set False, then
//                the standard import of metadata objects identifiers using the DataExchange
//                subsystem will be skipped (the same will happen if there is no DataExchange subsystem).
//
Procedure BeforeExportingIDsMetadataObjectsInSubordinatedADBNode(StandardProcessing) Export
	
	
	
EndProcedure

// Fills the structure with arrays of supported versions of
// all application interfaces that are subject to versioning using APIs as keys.
// Provides the functionality of InterfaceVersion Web-service.
// during the implementation the body of the procedure shall be changed so it will return relevant version sets (see ex.below).
//
// Parameters:
// SupportedVersionStructure - Structure:
//  Key - Name of
//  the application interface, Value - Array(Row) - supported versions of application interface.
//
// Example of implementation:
//
//  // FileTransferServer
//  VersionsArray = New Array;
//  VersionsArray.Add("1.0.1.1");
//  VersionsArray.Add("1.0.2.1"); 
//  SupportedVersionsStructure.Insert("FileTransferServer", VersionsArray);
//  // End FileTransferService
//
Procedure OnDefenitionSupportedVersionsOfSoftwareInterfaces(SupportedVersionStructure) Export
	
EndProcedure

// Parameters of the functional options that influence command interface and desktop.
//   For example if the values of functional option are
//   stored in the information register resources, then the parameters of functional
//   options can define the filters conditions by the register measurements. They will be applied during reading the value of this functional option.
//
// Parameters:
//   InterfaceOptions - Structure - Values of the functional options parameters specified for the command interface.
//       Key of the structure item defines the name of parameter and the item value - current value of the parameter.
//
// See also:
//   Global context methods
//   GetFunctionalInterfaceOption(), SetInterfaceFunctionalOptionsParameters() and GetInterfaceFunctionalOptionsParameters().
//
Procedure OnDefiningFunctionalInterfaceOptionsParameters(InterfaceOptions) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Outdated application interface.

// Outdated. It will be deleted in the next revision.See OnDefiningBasicFunctionalityGeneralParameters.
Procedure FormNamePersonalSettings(FormName) Export
	
EndProcedure

// Outdated. It will be deleted in the next revision.See OnDefiningBasicFunctionalityGeneralParameters.
Procedure GetMinRequiredPlatformVersion(CheckParameters) Export
	
EndProcedure

// Outdated. It will be deleted in the next revision.See OnAddMetadataObjectsRenaming.
Procedure FillTableMetadataObjectsRenaming(Total) Export
	
EndProcedure

// Outdated. It is required to use OnAddSessionParametersSettingHandlers.
// Returns a match of session parameters and handlers parameters to initialize them.
//
Function SessionParameterInitHandlers() Export
	
	// To specify handlers of session parameters, you should use template:
	// Handlers.Insert("<SessionParameterName>|<SessionParameterNamePrefix*>", "Handler");
	//
	// Note. * character is used in the end of
	//             the session parameter name and indicates that one handler will
	//             be called for initialization of all session parameters with the name that starts with the word SessionParameterNameStart.
	//
	
	Handlers = New Map;
	
	Return Handlers;
	
EndFunction

// Outdated. You shall use OnAddRefsSearchExceptions.
//
// Metadata objects the content of which should not be considered in the application business logic.
//
// Description:
//   The Objects versioning and Properties subsystems are set for the Products and services implementation document.
//   The document can be specified in other metadata objects - documents or registers.
//   Some references are relevant for the business logic (for example, move by registers) and should be shown to a user.
//   Another part of refs - "technology-generated" refs to document from the Object
//     versioning and Properties subsystems data should be hidden from a user while searching for refs to object. 
//     For example, when usage places are analyzed or in the subsystem of key attributes editing prohibition.
//   List of this "technology-generated" objects should be enumerated in this function.
//
// IMPORTANT:
//   To prevent empty "dead" refs, it is recommended to consider the
//   procedure of removal of the specified metadata objects.
//   For dimensions of information registers - using the Leading check
//     box selection, then the information register record will be deleted at the same time the ref specified in the dimension is deleted.
//   For other attributes of the specified objects - using subscription to the BeforeRemoval event of
//   all metadata objects types what can be written to attributes of the specified metadata objects.
//     It is required to find "technology-generated" objects in the handler in the
//     attributes of which the ref of the deleted object is specified and select the method of ref clearing: clear attribute value, delete table row or delete the whole object.
//
// ForExample:
// Array.Add(Metadata.InformationRegisters.ObjectsVersions);
// Array.Add(Metadata.InformationRegisters.ObjectsVersions.Attributes.VersionAuthor);
// Array.Add(InformationRegister.ObjectsVersions);
//
// Returns:
//   Array - Metadata objects or their attributes content of which should not be considered in the application business-logic.
//       * MetadataObject - Metadata object or its attribute.
//       * String - Full name of the metadata object or its attribute.
//
Function GetRefSearchExceptions() Export
	
	Array = New Array;
	
	Return Array;
	
EndFunction

Function StructureToString(StructureForTransformation, Separator = ",") Export
	
	Result = "";
	
	For Each Item In StructureForTransformation Do
		
		SeparatorChar = ?(IsBlankString(Result), "", Separator);
		
		Result = Result + SeparatorChar + Item.Key;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function StringToStructure(StringForTransformation, Separator = ",") Export
	
	Result	= New Structure;
	StringPropertySearch	= StringForTransformation;
	
	SeparatorPosition = StrFind(StringPropertySearch,Separator);
	While SeparatorPosition <> 0 Do
		Result.Insert(СокрЛП(Лев(StringPropertySearch, SeparatorPosition-1)));
		StringPropertySearch = Сред(StringPropertySearch, SeparatorPosition+1);
		SeparatorPosition = СтрНайти(StringPropertySearch,Separator);
	EndDo;
	Result.Insert(СокрЛП(StringPropertySearch));
	
	Return Result;
	
EndFunction

#EndRegion
