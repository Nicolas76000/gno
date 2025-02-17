package pager

import (
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
	"gno.land/p/demo/urequire"
)

func TestPager_GetPage(t *testing.T) {
	// Create a new AVL tree and populate it with some key-value pairs.
	tree := avl.NewTree()
	tree.Set("a", 1)
	tree.Set("b", 2)
	tree.Set("c", 3)
	tree.Set("d", 4)
	tree.Set("e", 5)

	t.Run("normal ordering", func(t *testing.T) {
		// Create a new pager.
		pager := NewPager(tree, 10, false)

		// Define test cases.
		tests := []struct {
			pageNumber int
			pageSize   int
			expected   []Item
		}{
			{1, 2, []Item{{Key: "a", Value: 1}, {Key: "b", Value: 2}}},
			{2, 2, []Item{{Key: "c", Value: 3}, {Key: "d", Value: 4}}},
			{3, 2, []Item{{Key: "e", Value: 5}}},
			{1, 3, []Item{{Key: "a", Value: 1}, {Key: "b", Value: 2}, {Key: "c", Value: 3}}},
			{2, 3, []Item{{Key: "d", Value: 4}, {Key: "e", Value: 5}}},
			{1, 5, []Item{{Key: "a", Value: 1}, {Key: "b", Value: 2}, {Key: "c", Value: 3}, {Key: "d", Value: 4}, {Key: "e", Value: 5}}},
			{2, 5, []Item{}},
		}

		for _, tt := range tests {
			page := pager.GetPageWithSize(tt.pageNumber, tt.pageSize)

			uassert.Equal(t, len(tt.expected), len(page.Items))

			for i, item := range page.Items {
				uassert.Equal(t, tt.expected[i].Key, item.Key)
				uassert.Equal(t, tt.expected[i].Value, item.Value)
			}
		}
	})

	t.Run("reversed ordering", func(t *testing.T) {
		// Create a new pager.
		pager := NewPager(tree, 10, true)

		// Define test cases.
		tests := []struct {
			pageNumber int
			pageSize   int
			expected   []Item
		}{
			{1, 2, []Item{{Key: "e", Value: 5}, {Key: "d", Value: 4}}},
			{2, 2, []Item{{Key: "c", Value: 3}, {Key: "b", Value: 2}}},
			{3, 2, []Item{{Key: "a", Value: 1}}},
			{1, 3, []Item{{Key: "e", Value: 5}, {Key: "d", Value: 4}, {Key: "c", Value: 3}}},
			{2, 3, []Item{{Key: "b", Value: 2}, {Key: "a", Value: 1}}},
			{1, 5, []Item{{Key: "e", Value: 5}, {Key: "d", Value: 4}, {Key: "c", Value: 3}, {Key: "b", Value: 2}, {Key: "a", Value: 1}}},
			{2, 5, []Item{}},
		}

		for _, tt := range tests {
			page := pager.GetPageWithSize(tt.pageNumber, tt.pageSize)

			uassert.Equal(t, len(tt.expected), len(page.Items))

			for i, item := range page.Items {
				uassert.Equal(t, tt.expected[i].Key, item.Key)
				uassert.Equal(t, tt.expected[i].Value, item.Value)
			}
		}
	})
}

func TestPager_GetPageByPath(t *testing.T) {
	// Create a new AVL tree and populate it with some key-value pairs.
	tree := avl.NewTree()
	for i := 0; i < 50; i++ {
		tree.Set(ufmt.Sprintf("key%d", i), i)
	}

	// Create a new pager.
	pager := NewPager(tree, 10, false)

	// Define test cases.
	tests := []struct {
		rawURL       string
		expectedPage int
		expectedSize int
	}{
		{"/r/foo:bar/baz?size=10&page=1", 1, 10},
		{"/r/foo:bar/baz?size=10&page=2", 2, 10},
		{"/r/foo:bar/baz?page=3", 3, pager.DefaultPageSize},
		{"/r/foo:bar/baz?size=20", 1, 20},
		{"/r/foo:bar/baz", 1, pager.DefaultPageSize},
	}

	for _, tt := range tests {
		page, err := pager.GetPageByPath(tt.rawURL)
		urequire.NoError(t, err, ufmt.Sprintf("GetPageByPath(%s) returned error: %v", tt.rawURL, err))

		uassert.Equal(t, tt.expectedPage, page.PageNumber)
		uassert.Equal(t, tt.expectedSize, page.PageSize)
	}
}

func TestPage_Picker(t *testing.T) {
	// Create a new AVL tree and populate it with some key-value pairs.
	tree := avl.NewTree()
	tree.Set("a", 1)
	tree.Set("b", 2)
	tree.Set("c", 3)
	tree.Set("d", 4)
	tree.Set("e", 5)

	// Create a new pager.
	pager := NewPager(tree, 10, false)

	// Define test cases.
	tests := []struct {
		pageNumber int
		pageSize   int
		expected   string
	}{
		{1, 2, "**1** | [2](?page=2) | [3](?page=3)"},
		{2, 2, "[1](?page=1) | **2** | [3](?page=3)"},
		{3, 2, "[1](?page=1) | [2](?page=2) | **3**"},
	}

	for _, tt := range tests {
		page := pager.GetPageWithSize(tt.pageNumber, tt.pageSize)

		ui := page.Picker()
		uassert.Equal(t, tt.expected, ui)
	}
}

func TestPager_UI_WithManyPages(t *testing.T) {
	// Create a new AVL tree and populate it with many key-value pairs.
	tree := avl.NewTree()
	for i := 0; i < 100; i++ {
		tree.Set(ufmt.Sprintf("key%d", i), i)
	}

	// Create a new pager.
	pager := NewPager(tree, 10, false)

	// Define test cases for a large number of pages.
	tests := []struct {
		pageNumber int
		pageSize   int
		expected   string
	}{
		// XXX: -1
		// XXX: 0
		{1, 10, "**1** | [2](?page=2) | [3](?page=3) | … | [10](?page=10)"},
		{2, 10, "[1](?page=1) | **2** | [3](?page=3) | [4](?page=4) | … | [10](?page=10)"},
		{3, 10, "[1](?page=1) | [2](?page=2) | **3** | [4](?page=4) | [5](?page=5) | … | [10](?page=10)"},
		{4, 10, "[1](?page=1) | [2](?page=2) | [3](?page=3) | **4** | [5](?page=5) | [6](?page=6) | … | [10](?page=10)"},
		{5, 10, "[1](?page=1) | … | [3](?page=3) | [4](?page=4) | **5** | [6](?page=6) | [7](?page=7) | … | [10](?page=10)"},
		{6, 10, "[1](?page=1) | … | [4](?page=4) | [5](?page=5) | **6** | [7](?page=7) | [8](?page=8) | … | [10](?page=10)"},
		{7, 10, "[1](?page=1) | … | [5](?page=5) | [6](?page=6) | **7** | [8](?page=8) | [9](?page=9) | [10](?page=10)"},
		{8, 10, "[1](?page=1) | … | [6](?page=6) | [7](?page=7) | **8** | [9](?page=9) | [10](?page=10)"},
		{9, 10, "[1](?page=1) | … | [7](?page=7) | [8](?page=8) | **9** | [10](?page=10)"},
		{10, 10, "[1](?page=1) | … | [8](?page=8) | [9](?page=9) | **10**"},
		// XXX: 11
	}

	for _, tt := range tests {
		page := pager.GetPageWithSize(tt.pageNumber, tt.pageSize)

		ui := page.Picker()
		uassert.Equal(t, tt.expected, ui)
	}
}

func TestPager_ParseQuery(t *testing.T) {
	// Create a new AVL tree and populate it with some key-value pairs.
	tree := avl.NewTree()
	tree.Set("a", 1)
	tree.Set("b", 2)
	tree.Set("c", 3)
	tree.Set("d", 4)
	tree.Set("e", 5)

	// Create a new pager.
	pager := NewPager(tree, 10, false)

	// Define test cases.
	tests := []struct {
		rawURL        string
		expectedPage  int
		expectedSize  int
		expectedError bool
	}{
		{"/r/foo:bar/baz?size=2&page=1", 1, 2, false},
		{"/r/foo:bar/baz?size=3&page=2", 2, 3, false},
		{"/r/foo:bar/baz?size=5&page=3", 3, 5, false},
		{"/r/foo:bar/baz?page=2", 2, pager.DefaultPageSize, false},
		{"/r/foo:bar/baz?size=3", 1, 3, false},
		{"/r/foo:bar/baz", 1, pager.DefaultPageSize, false},
		{"/r/foo:bar/baz?size=0&page=0", 1, pager.DefaultPageSize, false},
	}

	for _, tt := range tests {
		page, size, err := pager.ParseQuery(tt.rawURL)
		if tt.expectedError {
			uassert.Error(t, err, ufmt.Sprintf("ParseQuery(%s) expected error but got none", tt.rawURL))
		} else {
			urequire.NoError(t, err, ufmt.Sprintf("ParseQuery(%s) returned error: %v", tt.rawURL, err))
			uassert.Equal(t, tt.expectedPage, page, ufmt.Sprintf("ParseQuery(%s) returned page %d, expected %d", tt.rawURL, page, tt.expectedPage))
			uassert.Equal(t, tt.expectedSize, size, ufmt.Sprintf("ParseQuery(%s) returned size %d, expected %d", tt.rawURL, size, tt.expectedSize))
		}
	}
}
