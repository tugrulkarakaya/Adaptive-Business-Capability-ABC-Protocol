package com.db.clientinsights.review.service

import com.db.clientinsights.review.domain.*
import org.springframework.stereotype.Service

@Service
class ReviewPageService {
    fun nextStep(summary: ReviewSummary?): SuggestedCheck {
        val first = summary?.checks?.firstOrNull { it.warningCount > 0 }
        return when (first?.id) {
            "rhp" -> SuggestedCheck("Check the relationship holder",
                "Some bookings link to a relationship holder with a flagged status. Review its status and date with the data owner.")
            "parent" -> SuggestedCheck("Check the parent status",
                "A possible parent has a flagged status. Check the affected booking links and the status date.")
            "booking" -> SuggestedCheck("Review the booking status",
                "Some active ICMS Booking Codes have an inactive, deleted or suspended status in cRDS. Ask the booking owner to confirm current use.")
            "contacts" -> SuggestedCheck("Confirm who uses this company",
                "No active contact was found in this database copy. Check current use with the company data owner.")
            "settlement" -> SuggestedCheck("Review bookings without routes",
                "Some bookings have no settlement route. Ask the booking owner whether they are still used, including through other processes.")
            "confirmation" -> SuggestedCheck("Check the confirmation setup",
                "Some routed bookings have no confirmation route. Confirm the expected setup with the account owner.")
            else -> SuggestedCheck("Compare the parent links",
                "Check which bookings lead to each parent. Resolve missing information before deciding whether any record should change.")
        }
    }

    fun evidence(row: ReviewEvidence): EvidenceRecord {
        fun field(label: String, value: Any?) = EvidenceField(label, value?.toString()?.takeIf(String::isNotBlank) ?: "Unknown")
        fun check(label: String, value: Int?) = field(label, when (value) { 1 -> "Flagged"; 0 -> "No flag"; else -> null })
        return EvidenceRecord(row.bookingCode ?: "Booking code unavailable", row.bookingId?.toString() ?: "Unknown",
            row.settlementSystemName ?: "Unknown system", row.settlementMethodName ?: "Unknown method",
            row.ultimateParentName ?: row.ultimateParentId ?: "Parent unknown", listOf(
                EvidenceGroup("Booking", listOf(field("Booking record ID", row.bookingId), field("Booking code", row.bookingCode),
                    field("Settlement system", row.settlementSystemName), field("System ID", row.settlementSystemId),
                    field("Settlement method", row.settlementMethodName), field("Method ID", row.settlementMethod),
                    field("ICMS screen cRDS ID", row.icmsUiDerivedCrdsId), field("cRDS booking status", row.crdsBookingStatus))),
                EvidenceGroup("Relationship", listOf(field("Relationship holder", row.rhpName), field("RHP ID", row.rhpId),
                    field("RHP status", row.rhpStatus), field("RHP status date", row.rhpStatusDate),
                    field("Possible parent", row.ultimateParentName), field("Parent ID", row.ultimateParentId),
                    field("Parent status", row.ultimateParentStatus), field("Parent status date", row.ultimateParentStatusDate),
                    field("Product system ID", row.productSystemId), field("Relationship result", row.resolutionState))),
                EvidenceGroup("Contacts and routes", listOf(field("Active contacts", row.activeContacts),
                    field("Settlement routes", row.settlementRouteCount), field("Account types", row.accountClasses),
                    field("Confirmation routes", row.confirmationRouteCount), field("Confirmation platforms", row.confirmationPlatforms),
                    field("Contact company names on platforms", row.activeContactPlatformNames))),
                EvidenceGroup("Day 1 checks", listOf(check("RHP status", row.rhpWarning), check("Parent status", row.parentWarning),
                    check("cRDS booking status", row.xrefWarning), check("No active contacts", row.contactsWarning),
                    check("No settlement routes", row.settlementWarning), check("No confirmation routes", row.confirmationWarning),
                    field("Confirmed warning points", row.confirmedPoints), field("Unanswered score checks", row.unknownChecks),
                    field("Complete score (out of 6)", row.unusedScore))),
                EvidenceGroup("Company and source details", listOf(field("ICMS company ID", row.leId), field("Company name", row.companyName),
                    field("Ultimate Parents", row.companyParentCount), field("Company booking count", row.logicalBookingCount),
                    field("Fully scored bookings", row.fullyScoredBookings), field("Company average score", row.companyUnusedScoreAvg),
                    field("Company minimum score", row.companyUnusedScoreMin), field("Company maximum score", row.companyUnusedScoreMax),
                    field("Parent associations", row.parentBusinessAssociations), field("Association confidence", row.parentAssociationConfidence),
                    field("Incorrect parent score", row.incorrectParentScore), field("AI state", row.associationState),
                    field("Platform-name source", row.contactPlatformNamesState), field("ICMS screen lookup", row.uiCrdsIdState),
                    field("Settlement count state", row.settlementRouteState), field("Account type state", row.accountClassesState),
                    field("Confirmation state", row.confirmationState), field("Company match policy", row.dbLeMappingState),
                    field("Hierarchy policy", row.hierarchyPolicyState), field("Source refresh state", row.sourceFreshnessState)))
            ))
    }
}
