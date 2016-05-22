
////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Returns VAT rate by transferred company
//
Function GetCompanyVATRate(Company) Export
	
	Return Company.DefaultVATRate;
	
EndFunction // GetCompanyVATRate()