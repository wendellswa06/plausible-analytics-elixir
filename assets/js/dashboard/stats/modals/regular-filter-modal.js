import React from "react";
import { withRouter } from 'react-router-dom'

import FilterTypeSelector from "../../components/filter-type-selector";
import Combobox from '../../components/combobox'
import { FILTER_GROUPS, parseQueryFilter, formatFilterGroup, formattedFilters, toFilterQuery, FILTER_TYPES } from '../../util/filters'
import { parseQuery } from '../../query'
import * as api from '../../api'
import { apiPath, siteBasePath } from '../../util/url'
import { shouldIgnoreKeypress } from '../../keybinding'
import { isFreeChoiceFilter } from "../../util/filters";

function getFormState(filterGroup, query) {
  return FILTER_GROUPS[filterGroup].reduce((result, filter) => {
    const {type, clauses} = parseQueryFilter(query, filter)

    return Object.assign(result, { [filter]: { type, clauses } })
  }, {})
}

function withIndefiniteArticle(word) {
  if (word.startsWith('UTM')) {
    return `a ${word}`
  } if (['a', 'e', 'i', 'o', 'u'].some((vowel) => word.toLowerCase().startsWith(vowel))) {
    return `an ${word}`
  }
  return `a ${word}`
}

class RegularFilterModal extends React.Component {
  constructor(props) {
    super(props)
    const query = parseQuery(props.location.search, props.site)
    const formState = getFormState(props.filterGroup, query)
    
    this.handleKeydown = this.handleKeydown.bind(this)
    this.state = { query, formState }
  }

  componentDidMount() {
    document.addEventListener("keydown", this.handleKeydown)
  }

  componentWillUnmount() {
    document.removeEventListener("keydown", this.handleKeydown);
  }

  handleKeydown(e) {
    if (shouldIgnoreKeypress(e)) return

    if (e.target.tagName === 'BODY' && e.key === 'Enter') {
      this.handleSubmit()
    }
  }

  handleSubmit() {
    const { formState } = this.state;

    const filters = Object.entries(formState).reduce((res, [filterKey, { type, clauses }]) => {
      if (clauses.length === 0) { return res }
      if (filterKey === 'country') { res.push({ filter: 'country_labels', value: clauses.map(clause => clause.label).join('|') }) }
      if (filterKey === 'region') { res.push({ filter: 'region_labels', value: clauses.map(clause => clause.label).join('|') }) }
      if (filterKey === 'city') { res.push({ filter: 'city_labels', value: clauses.map(clause => clause.label).join('|') }) }

      res.push({ filter: filterKey, value: toFilterQuery(type, clauses) })
      return res
    }, [])

    this.selectFiltersAndCloseModal(filters)
  }

  onComboboxSelect(filterName) {
    return (selection) => {
      this.setState(prevState => ({
        formState: Object.assign(prevState.formState, {
          [filterName]: Object.assign(prevState.formState[filterName], { clauses: selection })
        })
      }))
    }
  }

  onFilterTypeSelect(filterName) {
    return (newType) => {
      this.setState(prevState => ({
        formState: Object.assign(prevState.formState, {
          [filterName]: Object.assign(prevState.formState[filterName], { type: newType })
        })
      }))
    }
  }

  fetchOptions(filter) {
    return (input) => {
      const { query, formState } = this.state
      if (formState[filter].type === FILTER_TYPES.contains) {return Promise.resolve([])}

      const formFilters = Object.fromEntries(
        Object.entries(formState)
          .filter(([_filter, {_type, clauses}]) => clauses.length > 0)
          .map(([filter, {type, clauses}]) => [filter, toFilterQuery(type, clauses)])
      )
      const updatedQuery = this.queryForSuggestions(query, formFilters, filter)
      return api.get(apiPath(this.props.site, `/suggestions/${filter}`), updatedQuery, { q: input.trim() })
    }
  }

  queryForSuggestions(query, formFilters, filter) {
    return { ...query, filters: { ...query.filters, ...formFilters, [filter]: this.negate(formFilters[filter]) } }
  }

  negate(filterVal) {
    if (!filterVal) {
      return filterVal
    } else if (filterVal.startsWith('!')) {
      return filterVal
    } else if (filterVal.startsWith('~')) {
      return null
    } else {
      return '!' + filterVal
    }
  }

  selectedFilterType(filter) {
    return this.state.formState[filter].type
  }

  isDisabled() {
    return Object.entries(this.state.formState).every(([_key, { clauses }]) => clauses.length === 0)
  }

  selectFiltersAndCloseModal(filters) {
    const queryString = new URLSearchParams(window.location.search)

    filters.forEach((entry) => {
      if (entry.value) {
        queryString.set(entry.filter, entry.value)
      } else {
        queryString.delete(entry.filter)
      }
    })

    this.props.history.replace({ pathname: siteBasePath(this.props.site), search: queryString.toString() })
  }

  renderFilterInputs() {
    const filtersInGroup = FILTER_GROUPS[this.props.filterGroup]

    return filtersInGroup.map((filter) => {
      return (
        <div className="mt-4" key={filter}>
          <div className="text-sm font-medium text-gray-700 dark:text-gray-300">{formattedFilters[filter]}</div>
          <div className="grid grid-cols-11 mt-1">
            <div className="col-span-3 mr-2">
              <FilterTypeSelector forFilter={filter} onSelect={this.onFilterTypeSelect(filter)} selectedType={this.selectedFilterType(filter)}/>
            </div>
            <div className="col-span-8">
              <Combobox fetchOptions={this.fetchOptions(filter)} freeChoice={isFreeChoiceFilter(filter)} values={this.state.formState[filter].clauses} onSelect={this.onComboboxSelect(filter)} placeholder={`Select ${withIndefiniteArticle(formattedFilters[filter])}`}/>
            </div>
          </div>
        </div>
      )
    })
  }

  render() {
    const { filterGroup } = this.props
    const { query } = this.state
    const showClear = FILTER_GROUPS[filterGroup].some((filterName) => query.filters[filterName])

    return (
      <>
        <h1 className="text-xl font-bold dark:text-gray-100">Filter by {formatFilterGroup(filterGroup)}</h1>

        <div className="mt-4 border-b border-gray-300"></div>
        <main className="modal__content">
          <form className="flex flex-col" onSubmit={this.handleSubmit.bind(this)}>
            {this.renderFilterInputs()}

            <div className="mt-6 flex items-center justify-start">
              <button
                type="submit"
                className="button"
                disabled={this.isDisabled()}
              >
                Apply Filter
              </button>

              {showClear && (
                <button
                  type="button"
                  className="ml-2 button px-4 flex bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700 items-center"
                  onClick={() => {
                    const updatedFilters = FILTER_GROUPS[filterGroup].map((filterName) => ({ filter: filterName, value: null }))
                    this.selectFiltersAndCloseModal(updatedFilters)
                  }}
                >
                  <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                  Remove filter{FILTER_GROUPS[filterGroup].length > 1 ? 's' : ''}
                </button>
              )}
            </div>
          </form>
        </main>
      </>
    )
  }
}

export default withRouter(RegularFilterModal)
