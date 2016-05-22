////////////////////////////////////////////////////////////////////////////////
// Subsystem "Prohibition of object attributes editing"
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Define metadata objects in the managers modules of which
// the ability to edit attributes is restricted using the GetLockedOjectAttributes export function.
//
// Parameters:
//   Objects - Map - as a key, specify a full name
//                            of metadata object connected to subsystem "Prohibition of object attributes editing";
//                            As a value - empty row.
//
// Example: 
//   Objects.Insert(Metadata.Documents.CustomerOrder.FullName(), "");
//
Procedure OnDetermineObjectsWithLockedAttributes(Objects) Export
	
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.FullName(), "GetObjectAttributesBeingLocked");
	Objects.Insert(Metadata.Catalogs.ContactInformationTypes.FullName(), "GetObjectAttributesBeingLocked");
	Objects.Insert(Metadata.Catalogs.AccrualAndDeductionKinds.FullName(), "GetObjectAttributesBeingLocked");
	Objects.Insert(Metadata.Catalogs.CounterpartyContracts.FullName(), "GetObjectAttributesBeingLocked");
	Objects.Insert(Metadata.Catalogs.CashRegisters.FullName(), "GetObjectAttributesBeingLocked");
	Objects.Insert(Metadata.Catalogs.ProductsAndServices.FullName(), "GetObjectAttributesBeingLocked");
	Objects.Insert(Metadata.Catalogs.ExchangeWithPeripheralsOfflineRules.FullName(), "GetObjectAttributesBeingLocked");
	Objects.Insert(Metadata.Catalogs.StructuralUnits.FullName(), "GetObjectAttributesBeingLocked");
	Objects.Insert(Metadata.Catalogs.POSTerminals.FullName(), "GetObjectAttributesBeingLocked");
	
EndProcedure

#EndRegion
