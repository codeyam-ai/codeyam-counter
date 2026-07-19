package com.codeyam.android

import com.codeyam.android.ui.MainViewModel
import org.junit.Assert.assertEquals
import org.junit.Test

class MainViewModelTest {

    @Test
    fun testIncrement() {
        val viewModel = MainViewModel()
        assertEquals(0, viewModel.count.value)
        viewModel.increment()
        assertEquals(1, viewModel.count.value)
    }

    @Test
    fun testDecrement() {
        val viewModel = MainViewModel()
        assertEquals(0, viewModel.count.value)
        viewModel.decrement()
        assertEquals(-1, viewModel.count.value)
    }

    // The ViewModel reflects a seeded initial count — the contract that lets a
    // CodeYam scenario seed `count` into SharedPreferences and have the app show
    // that value at launch (a no-arg construction still defaults to 0).
    @Test
    fun testSeededInitialCount() {
        val viewModel = MainViewModel(7)
        assertEquals(7, viewModel.count.value)
        viewModel.increment()
        assertEquals(8, viewModel.count.value)
    }
}
