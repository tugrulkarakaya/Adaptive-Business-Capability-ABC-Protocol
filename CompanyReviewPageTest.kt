package com.db.clientinsights.review

import org.hamcrest.Matchers.*
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.transaction.annotation.Transactional

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class CompanyReviewPageTest(
    @param:Autowired private val mvc: MockMvc,
    @param:Autowired private val jdbc: JdbcTemplate
) {
    @Test
    fun `search applies to both the count and company pages`() {
        mvc.get("/api/day1/companies/count?q=energy").andExpect { jsonPath("$.companies") { value(1) } }
        mvc.get("/api/day1/companies?q=ENERGY").andExpect {
            jsonPath("$.items.length()") { value(1) }
            jsonPath("$.items[0].companyId") { value(3) }
        }
        mvc.get("/api/day1/companies?q=248").andExpect { jsonPath("$.items[0].companyId") { value(248) } }
        mvc.get("/api/day1/companies/count?q=%").andExpect { jsonPath("$.companies") { value(0) } }
        mvc.get("/api/day1/companies/count?q=missing").andExpect { jsonPath("$.companies") { value(0) } }
        mvc.get("/api/day1/companies?q=" + "a".repeat(121)).andExpect { status { isBadRequest() } }
    }

    @Test
    fun `summary covers all bookings when only one parent is displayed`() {
        mvc.get("/api/day1/companies/248/review?parentSize=1").andExpect {
            status { isOk() }
            jsonPath("$.summary.bookingCount") { value(3) }
            jsonPath("$.summary.parentCount") { value(3) }
            jsonPath("$.summary.fullyScoredBookings") { value(1) }
            jsonPath("$.summary.checks.length()") { value(6) }
            jsonPath("$.summary.checks[5].notCheckedCount") { value(1) }
            jsonPath("$.parents.items.length()") { value(1) }
            jsonPath("$.parents.hasNext") { value(true) }
        }
        mvc.get("/api/day1/companies/248/review?parentPage=1&parentSize=1").andExpect {
            jsonPath("$.summary.bookingCount") { value(3) }
            jsonPath("$.parents.items[0].parentId") { value("PARENT-2") }
        }
    }

    @Test
    @Transactional
    fun `repeated relationship rows do not increase booking or warning counts`() {
        jdbc.update("INSERT INTO review_evidence SELECT * FROM review_evidence WHERE booking_id=1")
        mvc.get("/api/day1/companies/248/review").andExpect {
                jsonPath("$.summary.bookingCount") { value(3) }
                jsonPath("$.summary.checks[0].warningCount") { value(3) }
                jsonPath("$.parents.items[0].bookingCount") { value(1) }
            }
    }

    @Test
    fun `review handles missing inactive and nonqualifying companies`() {
        mvc.get("/api/day1/companies/123456/review").andExpect { status { isNotFound() } }
        mvc.get("/api/day1/companies/999/review").andExpect { jsonPath("$.state") { value("INACTIVE_COMPANY") } }
        mvc.get("/api/day1/companies/47/review").andExpect {
            jsonPath("$.state") { value("NO_QUALIFYING_DETAIL") }
            jsonPath("$.summary") { value(nullValue()) }
        }
        mvc.get("/api/day1/companies/248/review?parentPage=-1").andExpect { status { isBadRequest() } }
        mvc.get("/api/day1/companies/248/review?parentSize=101").andExpect { status { isBadRequest() } }
    }

    @Test
    fun `web page and assets are served by Spring`() {
        mvc.get("/companies").andExpect { status { isOk() }; content { string(containsString("Legal Entities to review")) } }
        mvc.get("/assets/review.js").andExpect { status { isOk() } }
        mvc.get("/companies/248").andExpect { status { isOk() }; content { string(containsString("Show booking evidence")) } }
        mvc.get("/companies/248/evidence").andExpect { status { isOk() }; content { string(containsString("&lt;script&gt;alert(1)&lt;/script&gt;")) } }
    }
}
